$psake.use_exit_on_error = $true
properties {
    $baseDir = (Split-Path -parent $psake.build_script_dir)
    $counter = $buildCounter

    $tagName = git tag -l --points-at HEAD

    if ($tagName) {
        Write-Host "Found tag ${'$'}tagName"
        $isTagged = $true
    } else {
        Write-Host "No tag found for current commit"
        $isTagged = $false
    }

    $script:version="1.0.0"
    $script:packageVersion = $version
    $script:informationalVersion = $version
    $script:changeset = "abcdef"
    $nugetExe = "$env:ChocolateyInstall\bin\nuget.exe"
    $ftpHost="waws-prod-bay-001.ftp.azurewebsites.windows.net"
    $msbuildExe="${env:programFiles(x86)}\Microsoft Visual Studio\2017\BuildTools\MSBuild\15.0\Bin\msbuild.exe"
    $reportUnitExe = "$env:ChocolateyInstall\bin\ReportUnit.exe"
    $gitVersionExe = "$env:ChocolateyInstall\lib\GitVersion.Portable\tools\gitversion.exe"
}

Task default -depends Build
Task Build -depends Run-GitVersion, Build-Clickonce, Build-Web, Install-ChocoPkg, Test, Package
Task Deploy -depends Build, Deploy-DownloadZip, Deploy-Bootstrapper, Publish-Clickonce, Update-Homepage -description 'Versions, packages and pushes to MyGet'
Task Package -depends Clean-Artifacts, Version-Module, Install-ChocoPkg, Create-ModuleZipForRemoting, Pack-NuGet, Package-DownloadZip -description 'Versions the psd1 and packs the module and example package'
Task Push-Public -depends Push-Chocolatey, Push-GitHub, Publish-Web
Task All-Tests -depends Test, Integration-Test
Task Quick-Deploy -depends Run-GitVersion, Build-Clickonce, Build-web, Package, Deploy-DownloadZip, Deploy-Bootstrapper, Publish-Clickonce, Update-Homepage

task Run-GitVersion {
    $output = . $gitVersionExe
    $joined = $output -join "`n"
    $versionInfo = $joined | ConvertFrom-Json

    $prerelease = $versionInfo.PreReleaseLabel
    $sha = $versionInfo.Sha.Substring(0,8)
    $majorMinorPatch = $versionInfo.MajorMinorPatch
    $buildDate = Get-Date -Format "yyyyMMdd"
    $script:changeset = $versionInfo.Sha
    $script:version = $versionInfo.AssemblySemVer

    if ($isTagged) {
        $script:packageVersion = $versionInfo.LegacySemVer
        $script:informationalVersion = $versionInfo.InformationalVersion
    } else {
        $script:packageVersion = "$majorMinorPatch-$prerelease-$buildDate" + $(if ($counter) { "-$counter" })
        $script:informationalVersion = "$majorMinorPatch-$prerelease-$buildDate-$sha"
    }

    Write-Host "Assembly Semantic Version: $version"
    Write-Host "Assembly Informational Version: $informationalVersion"
    Write-Host "Package Version: $packageVersion"

    Write-Host "##teamcity[buildNumber '$packageVersion']"
}

task Create-ModuleZipForRemoting {
    if (Test-Path "$basedir\Boxstarter.Chocolatey\Boxstarter.zip") {
      Remove-Item "$baseDir\Boxstarter.Chocolatey\boxstarter.zip" -Recurse -Force
    }
    if(!(Test-Path "$baseDir\buildArtifacts")){
        mkdir "$baseDir\buildArtifacts"
    }
    Remove-Item "$env:temp\Boxstarter.zip" -Force -ErrorAction SilentlyContinue
    ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\buildartifacts\Boxstarter.zip" "$basedir\boxstarter.Common" | Out-Null
    ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\buildartifacts\Boxstarter.zip" "$basedir\boxstarter.WinConfig" | Out-Null
    ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\buildartifacts\Boxstarter.zip" "$basedir\boxstarter.bootstrapper" | Out-Null
    ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\buildartifacts\Boxstarter.zip" "$basedir\boxstarter.chocolatey" | Out-Null
    ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\buildartifacts\Boxstarter.zip" "$basedir\boxstarter.config" | Out-Null
    ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\buildartifacts\Boxstarter.zip" "$basedir\LICENSE.txt" | Out-Null
    ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\buildartifacts\Boxstarter.zip" "$basedir\NOTICE.txt" | Out-Null
    if($taskList -eq 'test'){
      ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\buildartifacts\Boxstarter.zip" "$basedir\Chocolatey" | Out-Null
    }
    Move-Item "$basedir\buildartifacts\Boxstarter.zip" "$basedir\boxstarter.chocolatey\Boxstarter.zip"
}

task Build-ClickOnce -depends Install-MSBuild, Install-Win8SDK, Restore-NuGetPackages {
    Update-AssemblyInfoFiles $version $changeset
    exec { .$msbuildExe "$baseDir\Boxstarter.ClickOnce\Boxstarter.WebLaunch.csproj" /t:Clean /v:minimal }
    exec { .$msbuildExe "$baseDir\Boxstarter.ClickOnce\Boxstarter.WebLaunch.csproj" /t:Build /v:minimal }
}

task Build-Web -depends Install-MSBuild, Restore-NuGetPackages {
    exec { .$msbuildExe "$baseDir\Web\Web.csproj" /t:Clean /v:minimal }
    exec { .$msbuildExe "$baseDir\Web\Web.csproj" /t:Build /v:minimal /p:DownloadNuGetExe="true" }
    Copy-Item "$baseDir\packages\bootstrap.3.0.2\content\*" "$baseDir\Web" -Recurse -Force -ErrorAction SilentlyContinue
}

task Publish-ClickOnce -depends Install-MSBuild {
    exec { .$msbuildExe "$baseDir\Boxstarter.ClickOnce\Boxstarter.WebLaunch.csproj" /t:Publish /v:minimal /p:ApplicationVersion="$version" }
    Remove-Item "$basedir\web\Launch" -Recurse -Force -ErrorAction SilentlyContinue
    MkDir "$basedir\web\Launch"
    Set-Content "$basedir\web\Launch\.gitattributes" -Value "* -text"
    Copy-Item "$basedir\Boxstarter.Clickonce\bin\Debug\App.Publish\*" "$basedir\web\Launch" -Recurse -Force
}

task Publish-Web -depends Install-MSBuild, Install-WebDeploy {
    exec { .$msbuildExe "$baseDir\Web\Web.csproj" /p:DeployOnBuild=true /p:PublishProfile="boxstarter - Web Deploy" /p:VisualStudioVersion=12.0 /p:Password=$env:BOXSTARTER_PUBLISH_PASSWORD }
}

Task Test -depends Install-ChocoPkg, Pack-NuGet, Create-ModuleZipForRemoting {
    Push-Location "$baseDir"
    $pesterDir = "$env:ChocolateyInstall\lib\Pester"
    $pesterTestResultsFile = "$baseDir\buildArtifacts\TestResults.xml"
    $pesterTestResultsHtmlFile = "$baseDir\buildArtifacts\TestResults.html"

    if($testName){
        ."$pesterDir\tools\bin\Pester.bat" $baseDir/Tests -testName $testName -OutputFile $pesterTestResultsFile -OutputFormat NUnitXml
    }
    else{
        ."$pesterDir\tools\bin\Pester.bat" $baseDir/Tests -OutputFile $pesterTestResultsFile -OutputFormat NUnitXml
    }

    if($LastExitCode -ne 0) {
        # Generate HTML version of report
        if(Test-Path $pesterTestResultsFile) {
            .$reportUnitExe $pesterTestResultsFile $pesterTestResultsHtmlFile
        }

        throw 'There were failed unit tests.'
    }

    Pop-Location
}

Task Integration-Test -depends Pack-NuGet, Create-ModuleZipForRemoting {
    Push-Location "$baseDir"
    $pesterDir = "$env:ChocolateyInstall\lib\Pester"
    if($testName){
        exec {."$pesterDir\tools\bin\Pester.bat" $baseDir/IntegrationTests -testName $testName}
    }
    else{
        exec {."$pesterDir\tools\bin\Pester.bat" $baseDir/IntegrationTests }
    }
    Pop-Location
}

Task Version-Module -description 'Stamps the psd1 with the version and last changeset SHA' {
    Get-ChildItem "$baseDir\**\*.psd1" | ForEach-Object {
       $path = $_
        (Get-Content $path) |
            ForEach-Object {$_ -replace "^ModuleVersion = '.*'`$", "ModuleVersion = '$version'" } |
                ForEach-Object {$_ -replace "^PrivateData = '.*'`$", "PrivateData = '$changeset'" } |
                    Set-Content $path
    }
    (Get-Content "$baseDir\BuildScripts\bootstrapper.ps1") |
        ForEach-Object {$_ -replace "Version = .*`$", "Version = `"$version`"," } |
            Set-Content "$baseDir\BuildScripts\bootstrapper.ps1"
}

Task Clean-Artifacts {
    if (Test-Path "$baseDir\buildArtifacts") {
      Remove-Item "$baseDir\buildArtifacts" -Recurse -Force
    }

    mkdir "$baseDir\buildArtifacts"
    mkdir "$baseDir\buildArtifacts\tempNuGetFolders"
    mkdir "$baseDir\buildArtifacts\tempNuGetFolders\Boxstarter.Azure"
    mkdir "$baseDir\buildArtifacts\tempNuGetFolders\Boxstarter.Bootstrapper"
    mkdir "$baseDir\buildArtifacts\tempNuGetFolders\Boxstarter.Chocolatey"
    mkdir "$baseDir\buildArtifacts\tempNuGetFolders\Boxstarter.Common"
    mkdir "$baseDir\buildArtifacts\tempNuGetFolders\Boxstarter.HyperV"
    mkdir "$baseDir\buildArtifacts\tempNuGetFolders\Boxstarter.TestRunner"
    mkdir "$baseDir\buildArtifacts\tempNuGetFolders\Boxstarter.WinConfig"
}

Task Pack-NuGet -depends Sign-PowerShellFiles -description 'Packs the modules and example packages' {
    if (Test-Path "$baseDir\buildPackages\*.nupkg") {
      Remove-Item "$baseDir\buildPackages\*.nupkg" -Force
    }

    PackDirectory "$baseDir\BuildPackages"
    PackDirectory "$baseDir\BuildScripts\nuget" -AddReleaseNotes -Version $packageVersion
    Move-Item "$baseDir\BuildScripts\nuget\*.nupkg" "$basedir\buildArtifacts"
}

Task Package-DownloadZip -depends Clean-Artifacts {
    if (Test-Path "$basedir\BuildArtifacts\Boxstarter.*.zip") {
      Remove-Item "$basedir\BuildArtifacts\Boxstarter.*.zip" -Force
    }

    exec { ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\BuildArtifacts\Boxstarter.$packageVersion.zip" "$basedir\LICENSE.txt" }
    exec { ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\BuildArtifacts\Boxstarter.$packageVersion.zip" "$basedir\NOTICE.txt" }
    exec { ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\BuildArtifacts\Boxstarter.$packageVersion.zip" "$basedir\buildscripts\bootstrapper.ps1" }
    exec { ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\BuildArtifacts\Boxstarter.$packageVersion.zip" "$basedir\buildscripts\Setup.bat" }
}

Task Deploy-DownloadZip -depends Package-DownloadZip {
    Remove-Item "$basedir\web\downloads" -Recurse -Force -ErrorAction SilentlyContinue
    mkdir "$basedir\web\downloads"
    Copy-Item "$basedir\BuildArtifacts\Boxstarter.$packageVersion.zip" "$basedir\web\downloads"
}

Task Deploy-Bootstrapper {
    Remove-Item "$basedir\web\bootstrapper.ps1" -Force -ErrorAction SilentlyContinue
    Copy-Item "$basedir\buildscripts\bootstrapper.ps1" "$basedir\web\bootstrapper.ps1"
}

Task Push-Chocolatey -description 'Pushes the module to Chocolatey community sfeed' {
    exec {
        Get-ChildItem "$baseDir\buildArtifacts\*.nupkg" |
            ForEach-Object { cpush $_  }
    }
}

Task Push-GitHub {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
    $headers = @{
        Authorization = 'Basic ' + [Convert]::ToBase64String(
            [Text.Encoding]::ASCII.GetBytes("$($env:BOXSTARTER_GITHUB_USERNAME):$($env:BOXSTARTER_GITHUB_TOKEN)"));
    }

    $releaseNotes = Get-ReleaseNotes
    $postParams = ConvertTo-Json @{
        tag_name="v$packageVersion"
        target_commitish=$changeset
        name="v$packageVersion"
        body=$releaseNotes.DocumentElement.'#text'
    } -Compress

    $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/chocolatey/boxstarter/releases/latest" -Method GET -Headers $headers
    if($latest.tag_name -ne "v$packageVersion"){
        Write-Host "Creating release"
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/chocolatey/boxstarter/releases" -Method POST -Body $postParams -Headers $headers
        $uploadUrl = $response.upload_url.replace("{?name,label}","?name=boxstarter.$packageVersion.zip")
    }
    else {
        $uploadUrl = $latest.upload_url.replace("{?name,label}","?name=boxstarter.$packageVersion.zip")
    }

    Write-Host "Uploading $basedir\BuildArtifacts\Boxstarter.$packageVersion.zip to $uploadUrl"
    try {
        Invoke-RestMethod -Uri $uploadUrl -Method POST -ContentType "application/zip" -InFile "$basedir\BuildArtifacts\Boxstarter.$packageVersion.zip" -Headers $headers
    }
    catch{
        write-host $_ | Format-List * -force
    }
}

task Update-Homepage {
     $versionPattern="[0-9]+(\.([0-9]+|\*)){1,3}"
     $filename = "$baseDir\web\App_Code\Helper.cshtml"
     (Get-Content $filename) | ForEach-Object {$_ -replace $versionPattern, ($version) } | Set-Content $filename
}

task Get-ClickOnceStats {
    $creds = Get-Credential
    mkdir "$basedir\sitelogs" -ErrorAction silentlycontinue
    Push-Location "$basedir\sitelogs"
    $ftpScript = @"
user $($creds.UserName) $($creds.GetNetworkCredential().Password)
cd LogFiles/http/RawLogs
mget *
bye
"@
    $ftpScript | ftp -i -n $ftpHost
    if(!(Test-Path $env:ChocolateyInstall\lib\logparser*)) { choco install logparser --version=2.2.0.1 -y --no-progress }
    $logParser = "${env:programFiles(x86)}\Log Parser 2.2\LogParser.exe"
    .$logparser -i:w3c "SELECT Date, EXTRACT_VALUE(cs-uri-query,'package') as package, COUNT(*) as count FROM * where cs-uri-stem = '/launch/Boxstarter.WebLaunch.Application' Group by Date, package Order by Date, package" -rtp:-1
    Pop-Location
    Remove-Item "$basedir\sitelogs" -Recurse -Force
}

task Install-MSBuild {
    if(!(Test-Path "${env:programFiles(x86)}\Microsoft Visual Studio\2017\BuildTools\MSBuild\15.0\Bin\msbuild.exe")) {
        choco install visualstudio2017buildtools -params '--add Microsoft.VisualStudio.Workload.WebBuildTools' --version=15.8.7.0 --no-progress -y
        choco install microsoft-build-tools --version=15.0.26320.2 --no-progress -y
    }
}

task Install-Win8SDK {
    if(!(Test-Path "$env:ProgramFiles\Windows Kits\8.1\bin\x64\signtool.exe")) { choco install windows-sdk-8.1 --version=8.100.26654.0 -y --no-progress }
}

task Install-WebDeploy {
    if(!(Test-Path "$env:ProgramW6432\IIS\Microsoft Web Deploy V3")) { choco install webdeploy --version=3.6.20170627 -y --no-progress }
}

Task Restore-NuGetPackages {
    exec { .$nugetExe restore "$baseDir\Boxstarter.sln" }
}

task Install-ChocoPkg {
    MkDir $basedir\Boxstarter.Chocolatey\chocolatey -ErrorAction SilentlyContinue
    $chocoVersion = "1.1.0"
    $srcUrl = "https://community.chocolatey.org/api/v2/package/chocolatey/$chocoVersion"
    $targetFile = "chocolatey.$chocoVersion.nupkg"
    Push-Location $basedir\Boxstarter.Chocolatey\chocolatey
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

task Copy-PowerShellFiles -depends Clean-Artifacts {
    $tempNuGetDirectory = "$basedir\buildArtifacts\tempNuGetFolders"
    $exclude = @("bin", "obj", "*.pssproj")

    Copy-Item -Path $basedir\BuildScripts\chocolateyinstall.ps1 -Destination $tempNuGetDirectory
    Copy-Item -Path $basedir\BuildScripts\chocolateyUninstall.ps1 -Destination $tempNuGetDirectory
    Copy-Item -Path $basedir\BuildScripts\setup.ps1 -Destination $tempNuGetDirectory
    Copy-Item -Path $basedir\BuildScripts\nuget\Boxstarter.Azure.PreInstall.ps1 -Destination $tempNuGetDirectory
    Copy-Item -Path $basedir\BuildScripts\BoxstarterChocolateyInstall.ps1 -Destination $tempNuGetDirectory
    Copy-Item -Path $basedir\BoxstarterShell.ps1 -Destination $tempNuGetDirectory
    Copy-Item -Path $basedir\BuildScripts\VERIFICATION.txt -Destination $tempNuGetDirectory

    Copy-Item -Path $basedir\Boxstarter.Azure\* -Recurse -Destination $tempNuGetDirectory\Boxstarter.Azure -Exclude $exclude
    Copy-Item -Path $basedir\Boxstarter.Bootstrapper\* -Recurse -Destination $tempNuGetDirectory\Boxstarter.Bootstrapper -Exclude $exclude
    Copy-Item -Path $basedir\Boxstarter.Chocolatey\* -Recurse -Destination $tempNuGetDirectory\Boxstarter.Chocolatey -Exclude $exclude
    Copy-Item -Path $basedir\Boxstarter.Common\* -Recurse -Destination $tempNuGetDirectory\Boxstarter.Common -Exclude $exclude
    Copy-Item -Path $basedir\Boxstarter.HyperV\* -Recurse -Destination $tempNuGetDirectory\Boxstarter.HyperV -Exclude $exclude
    Copy-Item -Path $basedir\Boxstarter.TestRunner\* -Recurse -Destination $tempNuGetDirectory\Boxstarter.TestRunner -Exclude $exclude
    Copy-Item -Path $basedir\Boxstarter.WinConfig\* -Recurse -Destination $tempNuGetDirectory\Boxstarter.WinConfig -Exclude $exclude
}

task Sign-PowerShellFiles -depends Copy-PowerShellFiles {
    $timestampServer = "http://timestamp.digicert.com"
    $certPfx = "$env:CHOCOLATEY_OFFICIAL_CERT"
    $certPasswordFile = "$env:CHOCOLATEY_OFFICIAL_CERT_PASSWORD"
    $tempNuGetDirectory = "$basedir\buildArtifacts\tempNuGetFolders"
    $powerShellFiles = Get-ChildItem -Path $tempNuGetDirectory -Recurse -Include @("*.ps1", "*.psm1", "*.psd1") -File

    if($certPfx -And $certPasswordFile -And (Test-Path $certPfx) -And (Test-Path $certPasswordFile)) {
        $certPassword = Get-Content "$env:CHOCOLATEY_OFFICIAL_CERT_PASSWORD"
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPfx, $certPassword)
    }
    elseif($env:STORE_CHOCOLATEY_OFFICIAL_CERT -eq 'true' -or $env:STORE_DEVTEST_CERT -eq 'true') {
        $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -like "*$($env:CERT_SUBJECT_NAME)*"
    }

    if($cert) {
        Set-AuthenticodeSignature -Filepath $powerShellFiles -Cert $cert -TimeStampServer $timestampServer -IncludeChain NotRoot -HashAlgorithm SHA256
    }
    else {
        Write-Host "Unable to sign PowerShell files, as unable to locate certificate and/or password."
    }
}

function PackDirectory($path, [switch]$AddReleaseNotes, $Version = $version){
    exec {
        $releaseNotes = Get-ReleaseNotes
        Get-ChildItem $path -Recurse -include *.nuspec |
            ForEach-Object {
                 if($AddReleaseNotes) {
                   [xml]$nuspec = Get-Content $_
                   $oldReleaseNotes = $nuspec.package.metadata.ChildNodes| Where-Object { $_.Name -eq 'releaseNotes' }
                   $newReleaseNotes = $nuspec.ImportNode($releaseNotes.DocumentElement, $true)
                   $nuspec.package.metadata.ReplaceChild($newReleaseNotes, $oldReleaseNotes) | Out-Null
                   $nuspec.Save($_)
                 }
                 .$nugetExe pack $_ -OutputDirectory $path -NoPackageAnalysis -version $Version
              }
    }
}

function Get-ReleaseNotes {
    [xml](Get-Content "$baseDir\BuildScripts\releaseNotes.xml")
}

# Borrowed from Luis Rocha's Blog (http://www.luisrocha.net/2009/11/setting-assembly-version-with-windows.html)
function Update-AssemblyInfoFiles ([string] $version, [string] $commit) {
    $assemblyVersionPattern = 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
    $fileVersionPattern = 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
    $assemblyInformationalVersionPattern = 'AssemblyInformationalVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'

    $fileCommitPattern = 'AssemblyTrademark\("([a-f0-9]{40})?"\)'
    $assemblyVersion = 'AssemblyVersion("' + $version + '")';
    $fileVersion = 'AssemblyFileVersion("' + $version + '")';
    $assemblyInformationalVersion = 'AssemblyInformationalVersion("' + $informationalVersion + '")';
    $commitVersion = 'AssemblyTrademark("' + $commit + '")';

    Get-ChildItem -path $baseDir -r -filter AssemblyInfo.cs | ForEach-Object {
        $filename = $_.Directory.ToString() + '\' + $_.Name
        $filename + ' -> ' + $version

        # If you are using a source control that requires to check-out files before
        # modifying them, make sure to check-out the file here.
        # For example, TFS will require the following command:
        # tf checkout $filename

        (Get-Content $filename) | ForEach-Object {
            ForEach-Object {$_ -replace $assemblyVersionPattern, $assemblyVersion } |
            ForEach-Object {$_ -replace $fileVersionPattern, $fileVersion } |
            ForEach-Object {$_ -replace $fileCommitPattern, $commitVersion } |
            ForEach-Object {$_ -replace $assemblyInformationalVersionPattern, $assemblyInformationalVersion }
        } | Set-Content $filename
    }
}
