$psake.use_exit_on_error = $true

function Test-IsReleaseBuildOS {
    (-Not ($PSVersionTable.PSEdition -eq 'Core' -And $PSVersionTable.Platform -ne 'Windows'))
}

Properties {
    $script:baseDir = (Split-Path -Parent $psake.build_script_dir)
    $script:counter = $buildCounter

    $tagName = git tag -l --points-at HEAD

    $script:isTagged = if ($tagName) {
        Write-Host "Found tag ${'$'}tagName"
        $true
    }
    else {
        Write-Host 'No tag found for current commit'
        $false
    }

    $script:version = '1.0.0'
    $script:packageVersion = $version
    $script:informationalVersion = $version
    $script:changeset = 'abcdef'
    $script:7z = if ( Test-IsReleaseBuildOS ) { "$env:chocolateyInstall/bin/7za.exe" } else { '7za' }
    $script:nugetExe = "$env:ChocolateyInstall/bin/nuget.exe"
    $script:msbuildExe = "${env:programFiles(x86)}/Microsoft Visual Studio/2017/BuildTools/MSBuild/15.0/Bin/msbuild.exe"
    $script:reportUnitExe = "$env:ChocolateyInstall/bin/ReportUnit.exe"
    $script:gitVersionExe = if (Test-IsReleaseBuildOS) { "$env:ChocolateyInstall/lib/GitVersion.Portable/tools/gitversion.exe" } else { 'gitversion' }

    $script:boxstarterModules = @(
        'Azure',
        'Bootstrapper',
        'Chocolatey',
        'Common',
        'HyperV',
        'TestRunner',
        'WinConfig' 
    )
}

Task default -depends Build
Task Build -depends Run-GitVersion, Build-Clickonce, Get-ChocolateyNugetPkg, Test, Package
Task Deploy -depends Build, Publish-Clickonce -description 'Versions, packages and pushes'
Task Compile-Modules-Only -depends Clean-Artifacts, Compile-Modules # just for testing, probably remove once done!
Task Package -depends Clean-Artifacts, Version-Module, Get-ChocolateyNugetPkg, Create-ModuleZipForRemoting, Pack-Chocolatey, Package-DownloadZip -description 'Versions the psd1 and packs the module and example package'
Task All-Tests -depends Test, Integration-Test
Task Quick-Deploy -depends Run-GitVersion, Build-Clickonce, Package, Publish-Clickonce

Task Run-GitVersion {
    Write-Host 'Testing to see if running on TeamCity...'

    if ($env:TEAMCITY_VERSION) {
        Write-Host 'Running on TeamCity.'

        Write-Host 'Running GitVersion with output type build server...'
        . $gitVersionExe /output buildserver /nocache /nofetch

        Write-Host 'Running GitVersion again with output type json...'
        $output = . $gitVersionExe /output json /nocache /nofetch
    }
    else {
        Write-Host 'Not running on TeamCity.'

        Write-Host 'Running GitVersion with output type json...'

        $output = . $gitVersionExe /output json /nocache
    }

    Write-Host 'Writing output variable...'
    Write-Host $output

    $joined = $output -join "`n"
    Write-Host 'Writing joined variable...'
    Write-Host $joined

    $versionInfo = $joined | ConvertFrom-Json

    $sha = $versionInfo.Sha.Substring(0, 8)
    $majorMinorPatch = $versionInfo.MajorMinorPatch
    $buildDate = Get-Date -Format 'yyyyMMdd'
    $script:changeset = $versionInfo.Sha
    $script:version = $versionInfo.AssemblySemVer

    # Having a pre-release label of greater than 10 characters can cause problems when trying to run choco pack.
    # Since we typically only see this when building a local feature branch, or a PR, let's just trim it down to
    # the 10 character limit, and move on.
    if ($versionInfo.PreReleaseLabel -And $versionInfo.PreReleaseLabel.Length -gt 10) {
        $prerelease = $versionInfo.PreReleaseLabel.Replace('-', '').Substring(0, 10)
    }

    # Chocolatey doesn't support a prerelease that starts with a digit.
    # If we see a digit here, merely replace it with an `a` to get around this.
    if ($prerelease -match '^/d') {
        $prerelease = "a$($prerelease.Substring(1,9))"
    }

    if ($isTagged) {
        $script:packageVersion = $versionInfo.LegacySemVer
        $script:informationalVersion = $versionInfo.InformationalVersion
    }
    else {
        $script:packageVersion = "$majorMinorPatch" + $(if ($prerelease) { "-$prerelease" } else { '-rc' }) + "-$buildDate" + $(if ($counter) { "-$counter" })
        $script:informationalVersion = "$majorMinorPatch" + $(if ($prerelease) { "-$prerelease" } else { '-rc' }) + "-$buildDate-$sha"
    }

    Write-Host "Assembly Semantic Version: $version"
    Write-Host "Assembly Informational Version: $informationalVersion"
    Write-Host "Package Version: $packageVersion"

    Write-Host "##teamcity[buildNumber '$packageVersion']"
}

Task Create-ModuleZipForRemoting -depends Compile-Modules, Get-ChocolateyNugetPkg {
    if (Test-Path "$baseDir/Boxstarter.Chocolatey/Boxstarter.zip") {
        Remove-Item "$baseDir/Boxstarter.Chocolatey/Boxstarter.zip" -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (!(Test-Path "$baseDir/buildArtifacts")) {
        New-Item -ItemType Directory "$baseDir/buildArtifacts" | Out-Null
    }
    Remove-Item "$env:temp/Boxstarter.zip" -Force -ErrorAction SilentlyContinue
    $boxstarterZip = "$baseDir/buildArtifacts/Boxstarter.zip"

    @('Common', 'WinConfig', 'Bootstrapper', 'Chocolatey') | ForEach-Object {
        ."$7z" a -tzip "$boxstarterZip" "$baseDir/buildArtifacts/tempNuGetFolders/Boxstarter.$_" | Out-Null
    }

    ."$7z" a -tzip "$boxstarterZip" "$baseDir/Boxstarter.config" | Out-Null
    ."$7z" a -tzip "$boxstarterZip" "$baseDir/LICENSE.txt" | Out-Null
    ."$7z" a -tzip "$boxstarterZip" "$baseDir/NOTICE.txt" | Out-Null
    if ($taskList -eq 'test') {
        ."$7z" a -tzip $boxstarterZip "$basedir/Chocolatey" | Out-Null
    }
    Copy-Item $boxstarterZip "$baseDir/buildArtifacts/tempNuGetFolders/Boxstarter.Chocolatey/"
    Move-Item $boxstarterZip "$basedir/Boxstarter.Chocolatey/Boxstarter.zip"
}

Task Build-ClickOnce -depends Install-MSBuild, Install-Win8SDK, Restore-NuGetPackages -precondition { Test-IsReleaseBuildOS } {
    Update-AssemblyInfoFiles $version $changeset
    Exec { .$msbuildExe "$baseDir/Boxstarter.ClickOnce/Boxstarter.WebLaunch.csproj" /t:Clean /v:minimal }
    Exec { .$msbuildExe "$baseDir/Boxstarter.ClickOnce/Boxstarter.WebLaunch.csproj" /t:Build /v:minimal }
}

Task Publish-ClickOnce -depends Install-MSBuild {
    Exec { .$msbuildExe "$baseDir/Boxstarter.ClickOnce/Boxstarter.WebLaunch.csproj" /t:Publish /v:minimal /p:ApplicationVersion="$version" }
    Remove-Item "$basedir/web/Launch" -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory "$basedir/web/Launch" | Out-Null
    Set-Content "$basedir/web/Launch/.gitattributes" -Value '* -text'
    Copy-Item "$basedir/Boxstarter.Clickonce/bin/Debug/App.Publish/*" "$basedir/web/Launch" -Recurse -Force
}

Task Test -depends Get-ChocolateyNugetPkg, Pack-Chocolatey  {
    Push-Location "$baseDir"
    $pesterDir = "$env:ChocolateyInstall/lib/Pester"
    $pesterTestResultsFile = "$baseDir/buildArtifacts/TestResults.xml"
    $pesterTestResultsHtmlFile = "$baseDir/buildArtifacts/TestResults.html"

    if ($testName) {
        ."$pesterDir/tools/bin/Pester.bat" $baseDir/Tests -testName $testName -OutputFile $pesterTestResultsFile -OutputFormat NUnitXml
    }
    else {
        ."$pesterDir/tools/bin/Pester.bat" $baseDir/Tests -OutputFile $pesterTestResultsFile -OutputFormat NUnitXml
    }

    if ($LastExitCode -ne 0) {
        # Generate HTML version of report
        if (Test-Path $pesterTestResultsFile) {
            .$reportUnitExe $pesterTestResultsFile $pesterTestResultsHtmlFile
        }

        throw 'There were failed unit tests.'
    }

    Pop-Location
}

Task Integration-Test -depends Pack-Chocolatey, Create-ModuleZipForRemoting {
    Push-Location "$baseDir"
    $pesterDir = "$env:ChocolateyInstall/lib/Pester"
    if ($testName) {
        Exec { ."$pesterDir/tools/bin/Pester.bat" $baseDir/IntegrationTests -testName $testName }
    }
    else {
        Exec { ."$pesterDir/tools/bin/Pester.bat" $baseDir/IntegrationTests }
    }
    Pop-Location
}

Task Version-Module -description 'Stamps the psd1 with the version and last changeset SHA' {
    Get-ChildItem "$baseDir/**/*.psd1" | ForEach-Object {
        $path = $_
        (Get-Content $path) |
        ForEach-Object { $_ -replace "^ModuleVersion = '.*'`$", "ModuleVersion = '$version'" } |
        ForEach-Object { $_ -replace "^PrivateData = '.*'`$", "PrivateData = '$changeset'" } |
        Set-Content $path
    }
    (Get-Content "$baseDir/BuildScripts/bootstrapper.ps1") |
    ForEach-Object { $_ -replace "Version = .*`$", "Version = `"$packageVersion`"," } |
    Set-Content "$baseDir/BuildScripts/bootstrapper.ps1"
}

Task Clean-Artifacts {
    if (Test-Path "$baseDir/buildArtifacts") {
        Remove-Item "$baseDir/buildArtifacts" -Recurse -Force
    }

    New-Item -ItemType Directory "$baseDir/buildArtifacts" | Out-Null
    New-Item -ItemType Directory "$baseDir/buildArtifacts/tempNuGetFolders" | Out-Null
    foreach ($mod in $boxstarterModules) {
        New-Item -ItemType Directory "$baseDir/buildArtifacts/tempNuGetFolders/Boxstarter.$mod" | Out-Null
    }

    if (Test-Path "$baseDir/Boxstarter.Chocolatey/Boxstarter.zip") {
        Remove-Item "$baseDir/Boxstarter.Chocolatey/Boxstarter.zip" -Recurse -Force
    }

    if (Test-Path "$baseDir/Boxstarter.Chocolatey/chocolatey") {
        Remove-Item "$baseDir/Boxstarter.Chocolatey/chocolatey" -Recurse -Force
    }
}

Task Pack-Chocolatey -depends Compile-Modules, Sign-PowerShellFiles, Create-ModuleZipForRemoting -description 'Packs the modules and example packages' {
    if (Test-Path "$baseDir/BuildPackages/*.nupkg") {
        Remove-Item "$baseDir/BuildPackages/*.nupkg" -Force
    }

    PackDirectory "$baseDir/BuildPackages"
    PackDirectory "$baseDir/BuildScripts/nuget" -Version $packageVersion
    Move-Item "$baseDir/BuildScripts/nuget/*.nupkg" "$basedir/buildArtifacts"
}

Task Package-DownloadZip -depends Clean-Artifacts {
    if (Test-Path "$basedir/buildArtifacts/Boxstarter.*.zip") {
        Remove-Item "$basedir/buildArtifacts/Boxstarter.*.zip" -Force
    }

    Exec { ."$7z" a -tzip "$basedir/buildArtifacts/Boxstarter.$packageVersion.zip" "$basedir/LICENSE.txt" }
    Exec { ."$7z" a -tzip "$basedir/buildArtifacts/Boxstarter.$packageVersion.zip" "$basedir/NOTICE.txt" }
    Exec { ."$7z" a -tzip "$basedir/buildArtifacts/Boxstarter.$packageVersion.zip" "$basedir/BuildScripts/bootstrapper.ps1" }
    Exec { ."$7z" a -tzip "$basedir/buildArtifacts/Boxstarter.$packageVersion.zip" "$basedir/BuildScripts/setup.bat" }
}

Task Install-MSBuild -precondition { Test-IsReleaseBuildOS } {
    if (!(Test-Path "${env:programFiles(x86)}/Microsoft Visual Studio/2017/BuildTools/MSBuild/15.0/Bin/msbuild.exe")) {
        choco install visualstudio2017buildtools -params '--add Microsoft.VisualStudio.Workload.WebBuildTools' --version=15.8.7.0 --no-progress -y
        choco install microsoft-build-tools --version=15.0.26320.2 --no-progress -y
    }
}

Task Install-Win8SDK -precondition { Test-IsReleaseBuildOS } {
    if (!(Test-Path "$env:ProgramFiles/Windows Kits/8.1/bin/x64/signtool.exe")) { choco install windows-sdk-8.1 --version=8.100.26654.0 -y --no-progress }
}

Task Restore-NuGetPackages -precondition { Test-IsReleaseBuildOS } {
    Exec { .$nugetExe restore "$baseDir/Boxstarter.sln" -msbuildpath 'C:/Program Files (x86)/Microsoft Visual Studio/2017/BuildTools/MSBuild/15.0/Bin' }
}

Task Get-ChocolateyNugetPkg {
    $chocoNupkgDir = "$basedir/Boxstarter.Chocolatey/chocolatey"
    New-Item -ItemType Directory $chocoNupkgDir -ErrorAction SilentlyContinue | Out-Null
    $chocoVersion = '1.1.0'
    $srcUrl = "https://community.chocolatey.org/api/v2/package/chocolatey/$chocoVersion"
    $targetFile = "chocolatey.$chocoVersion.nupkg"
    Push-Location $chocoNupkgDir
    try {
        if (-Not (Test-Path $targetFile)) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $srcUrl -OutFile $targetFile
        }
    }
    finally {
        Pop-Location
    }
}

Task Compile-Modules {
    $tempNuGetDirectory = "$basedir/buildArtifacts/tempNuGetFolders"
    $exclude = @('bin', 'obj', '*.pssproj')

    foreach ($mod in $boxstarterModules) {
        $modSourceDir = "${basedir}/Boxstarter.${mod}"
        $modTemplateFile = Get-Item -Path "$modSourceDir/Boxstarter.${mod}.psm1"
        if (Test-Path $modTemplateFile) {
            Write-Host "> compile $modTemplateFile" -ForegroundColor Magenta
        }
        else {
            throw "expected module $modTemplateFile not found!"
        }

        $outDir = "$tempNuGetDirectory/Boxstarter.${mod}"
        $modOutFile = "${outDir}/Boxstarter.${mod}.psm1"
        if (-Not (Test-Path $outDir)) {
            New-Item -ItemType Directory $outDir | Out-Null
        }
        $modTemplateContent = Get-Content -Path $modTemplateFile -Raw

        # check if module has 'includes'
        if ($modTemplateContent -match '(?<line># --- INCLUDE (?<pattern>.*))') {
            $includedFiles = @()
            $Matches | ForEach-Object { 
                $includeLine = $_['line']
                $includePattern = $_['pattern'].Trim()

                $head = "#region RESOVED --- INCLUDE $includePattern"
                $tail = "#endregion RESOVED --- INCLUDE $includePattern"

                $modIncludes = Get-ChildItem -Path $modSourceDir | Where-Object { $_.Name -like $includePattern } | Sort-Object -Property Name | ForEach-Object {
                    $includedFiles += $_.FullName # will need later on to _not_ copy these files
                    "#region file $($_.Name)"
                    Get-Content $_.FullName -Raw
                    "#endregion file $($_.Name)"
                } 
                $modIncludes = $modIncludes -join "`n"
                $includeContent = @($head, $modIncludes, $tail) -join "`n"
                $modTemplateContent = $modTemplateContent.Replace($includeLine, $includeContent)
            }

            # write 'compiled' module
            $modTemplateContent | Out-File -FilePath $modOutFile -Encoding utf8
            # copy all other files that have not been included 
            Get-ChildItem -Path $modSourceDir | Where-Object { 
                ($_.FullName -notin $includedFiles) -And ($_.FullName -ne $modTemplateFile) 
            } | ForEach-Object {
                Copy-Item $_.FullName -Recurse -Destination $outDir -Exclude $exclude
            }
        } 
        else {
            Write-Host '! no INCLUDE instruction found, will copy everything' -ForegroundColor Red
            Copy-Item -Path "$modSourceDir/*" -Recurse -Destination $outDir -Exclude $exclude
        }
    }
    
}

Task Copy-PowerShellFiles -depends Clean-Artifacts, Compile-Modules {
    $tempNuGetDirectory = "$basedir/buildArtifacts/tempNuGetFolders"

    Copy-Item -Path $basedir/BuildScripts/chocolateyinstall.ps1 -Destination $tempNuGetDirectory
    Copy-Item -Path $basedir/BuildScripts/chocolateyUninstall.ps1 -Destination $tempNuGetDirectory
    Copy-Item -Path $basedir/BuildScripts/setup.ps1 -Destination $tempNuGetDirectory
    Copy-Item -Path $basedir/BuildScripts/nuget/Boxstarter.Azure.PreInstall.ps1 -Destination $tempNuGetDirectory
    Copy-Item -Path $basedir/BuildScripts/BoxstarterChocolateyInstall.ps1 -Destination $tempNuGetDirectory
    Copy-Item -Path $basedir/BoxstarterShell.ps1 -Destination $tempNuGetDirectory
    Copy-Item -Path $basedir/BuildScripts/VERIFICATION.txt -Destination $tempNuGetDirectory
}

Task Sign-PowerShellFiles -depends Copy-PowerShellFiles {
    $timestampServer = 'http://timestamp.digicert.com'
    $certPfx = "$env:CHOCOLATEY_OFFICIAL_CERT"
    $certPasswordFile = "$env:CHOCOLATEY_OFFICIAL_CERT_PASSWORD"
    $tempNuGetDirectory = "$basedir/buildArtifacts/tempNuGetFolders"
    $powerShellFiles = Get-ChildItem -Path $tempNuGetDirectory -Recurse -Include @('*.ps1', '*.psm1', '*.psd1') -File

    if ($certPfx -And $certPasswordFile -And (Test-Path $certPfx) -And (Test-Path $certPasswordFile)) {
        $certPassword = Get-Content "$env:CHOCOLATEY_OFFICIAL_CERT_PASSWORD"
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPfx, $certPassword)
    }
    elseif ($env:STORE_CHOCOLATEY_OFFICIAL_CERT -eq 'true' -or $env:STORE_DEVTEST_CERT -eq 'true') {
        $cert = Get-ChildItem Cert:/LocalMachine/My | Where-Object Subject -Like "*$($env:CERT_SUBJECT_NAME)*"
    }

    if ($cert) {
        Set-AuthenticodeSignature -FilePath $powerShellFiles -Cert $cert -TimestampServer $timestampServer -IncludeChain NotRoot -HashAlgorithm SHA256
        Set-AuthenticodeSignature -FilePath "$basedir/BuildScripts/bootstrapper.ps1" -Cert $cert -TimestampServer $timestampServer -IncludeChain NotRoot -HashAlgorithm SHA256
    }
    else {
        Write-Host 'Unable to sign PowerShell files, as unable to locate certificate and/or password.'
    }
}

function PackDirectory($path, $Version = $version) {
    Exec {
        $relPath = $path.Replace($baseDir, '')
        $relPath = if ($relPath.StartsWith('/')) { $relPath.Substring(1) } else { $relPath }
        Get-ChildItem $path -Recurse -Include *.nuspec |
        ForEach-Object {
            # docker run -ti -v "$($(pwd).Path):/tmp" -w /tmp chocolatey/choco /bin/bash
            if (Test-IsReleaseBuildOS) {
                choco pack $_ --OutputDirectory $path --version $version
            } 
            else {
                # WARNING: !!! DRAGONS AHEAD !!!
                $relItem = $_.FullName.Replace($baseDir, '')
                $relItem = if ($relItem.StartsWith('/')) { $relItem.Substring(1) } else { $relItem }
                docker run -t -v "${baseDir}:/tmp" -w /tmp chocolatey/choco /bin/bash -c "choco pack /tmp/$relItem --OutputDirectory /tmp/$relPath --version $Version"
            }
        }
    }
}

# Borrowed from Luis Rocha's Blog (http://www.luisrocha.net/2009/11/setting-assembly-version-with-windows.html)
function Update-AssemblyInfoFiles ([string] $version, [string] $commit) {
    $assemblyVersionPattern = 'AssemblyVersion/("[0-9]+(/.([0-9]+|/*)){1,3}"/)'
    $fileVersionPattern = 'AssemblyFileVersion/("[0-9]+(/.([0-9]+|/*)){1,3}"/)'
    $assemblyInformationalVersionPattern = 'AssemblyInformationalVersion/("[0-9]+(/.([0-9]+|/*)){1,3}"/)'

    $fileCommitPattern = 'AssemblyTrademark/("([a-f0-9]{40})?"/)'
    $assemblyVersion = 'AssemblyVersion("' + $version + '")'
    $fileVersion = 'AssemblyFileVersion("' + $version + '")'
    $assemblyInformationalVersion = 'AssemblyInformationalVersion("' + $informationalVersion + '")'
    $commitVersion = 'AssemblyTrademark("' + $commit + '")'

    Get-ChildItem -Path $baseDir -r -Filter AssemblyInfo.cs | ForEach-Object {
        $filename = $_.Directory.ToString() + '/' + $_.Name
        $filename + ' -> ' + $version

        # If you are using a source control that requires to check-out files before
        # modifying them, make sure to check-out the file here.
        # For example, TFS will require the following command:
        # tf checkout $filename

        (Get-Content $filename) | ForEach-Object {
            ForEach-Object { $_ -replace $assemblyVersionPattern, $assemblyVersion } |
            ForEach-Object { $_ -replace $fileVersionPattern, $fileVersion } |
            ForEach-Object { $_ -replace $fileCommitPattern, $commitVersion } |
            ForEach-Object { $_ -replace $assemblyInformationalVersionPattern, $assemblyInformationalVersion }
        } | Set-Content $filename
    }
}
