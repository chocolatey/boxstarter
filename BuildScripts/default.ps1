$psake.use_exit_on_error = $true
properties {
    $baseDir = (Split-Path -parent $psake.build_script_dir)
    if(Get-Command Git -ErrorAction SilentlyContinue) {
        $versionTag = git tag | ? { $_ -match '^[0-9\.]*$' } | Select-Object -Last 1
        $version = $versionTag + "."
        $version += (git log $($version + '..') --pretty=oneline | measure-object).Count
        $changeset=(git log -1 $($versionTag + '..') --pretty=format:%H)
    }
    else {
        $version="1.0.0"
    }
    $nugetExe = "$env:ChocolateyInstall\bin\nuget.exe"
    $ftpHost="waws-prod-bay-001.ftp.azurewebsites.windows.net"
    $msbuildExe="${env:ProgramFiles(x86)}\MSBuild\12.0\Bin\msbuild.exe"
}

Task default -depends Build
Task Build -depends Build-Clickonce, Build-Web, Install-ChocoLib, Test, Package
Task Deploy -depends Build, Deploy-DownloadZip, Publish-Clickonce, Update-Homepage -description 'Versions, packages and pushes to MyGet'
Task Package -depends Clean-Artifacts, Version-Module, Pack-Nuget, Create-ModuleZipForRemoting, Package-DownloadZip -description 'Versions the psd1 and packs the module and example package'
Task Push-Public -depends Push-Chocolatey, Push-Github, Publish-Web
Task All-Tests -depends Test, Integration-Test
Task Quick-Deploy -depends Build-Clickonce, Build-web, Package, Deploy-DownloadZip, Publish-Clickonce, Update-Homepage

task Create-ModuleZipForRemoting {
    if (Test-Path "$basedir\Boxstarter.Chocolatey\Boxstarter.zip") {
      Remove-Item "$baseDir\Boxstarter.Chocolatey\boxstarter.zip" -Recurse -Force
    }
    if(!(Test-Path "$baseDir\buildArtifacts")){
        mkdir "$baseDir\buildArtifacts"
    }
    Remove-Item "$env:temp\Boxstarter.zip" -Force -ErrorAction SilentlyContinue
    ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\buildartifacts\Boxstarter.zip" "$basedir\boxstarter.Common" | out-Null
    ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\buildartifacts\Boxstarter.zip" "$basedir\boxstarter.WinConfig" | out-Null
    ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\buildartifacts\Boxstarter.zip" "$basedir\boxstarter.bootstrapper" | out-Null
    ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\buildartifacts\Boxstarter.zip" "$basedir\boxstarter.chocolatey" | out-Null
    ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\buildartifacts\Boxstarter.zip" "$basedir\boxstarter.config" | out-Null
    ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\buildartifacts\Boxstarter.zip" "$basedir\license.txt" | out-Null
    if($taskList -eq 'test'){
      ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\buildartifacts\Boxstarter.zip" "$basedir\Chocolatey" | out-Null
    }
    Move-Item "$basedir\buildartifacts\Boxstarter.zip" "$basedir\boxstarter.chocolatey\Boxstarter.zip"
}

task Build-ClickOnce -depends Install-MSBuild, Install-Win8SDK {
    Update-AssemblyInfoFiles $version $changeset
    exec { .$msbuildExe "$baseDir\Boxstarter.ClickOnce\Boxstarter.WebLaunch.csproj" /t:Clean /v:minimal }
    exec { .$msbuildExe "$baseDir\Boxstarter.ClickOnce\Boxstarter.WebLaunch.csproj" /t:Build /v:minimal }
}

task Build-Web -depends Install-MSBuild, Install-WebAppTargets {
    exec { .$msbuildExe "$baseDir\Web\Web.csproj" /t:Clean /v:minimal }
    exec { .$msbuildExe "$baseDir\Web\Web.csproj" /t:Build /v:minimal /p:DownloadNuGetExe="true" }
    copy-Item "$baseDir\packages\bootstrap.3.0.2\content\*" "$baseDir\Web" -Recurse -Force -ErrorAction SilentlyContinue
}

task Publish-ClickOnce -depends Install-MSBuild {
    exec { .$msbuildExe "$baseDir\Boxstarter.ClickOnce\Boxstarter.WebLaunch.csproj" /t:Publish /v:minimal /p:ApplicationVersion="$version.0" }
    Remove-Item "$basedir\web\Launch" -Recurse -Force -ErrorAction SilentlyContinue
    MkDir "$basedir\web\Launch"
    Set-Content "$basedir\web\Launch\.gitattributes" -Value "* -text"
    Copy-Item "$basedir\Boxstarter.Clickonce\bin\Debug\App.Publish\*" "$basedir\web\Launch" -Recurse -Force
}

task Publish-Web -depends Install-MSBuild, Install-WebDeploy {
    exec { .$msbuildExe "$baseDir\Web\Web.csproj" /p:DeployOnBuild=true /p:PublishProfile="boxstarter - Web Deploy" /p:VisualStudioVersion=12.0 /p:Password=$env:boxstarter_publish_password }
}

Task Test -depends Create-ModuleZipForRemoting {
    pushd "$baseDir"
    $pesterDir = "$env:ChocolateyInstall\lib\Pester"
    if($testName){
        exec {."$pesterDir\tools\bin\Pester.bat" $baseDir/Tests -testName $testName}
    }
    else{
        exec {."$pesterDir\tools\bin\Pester.bat" $baseDir/Tests }
    }
    popd
}

Task Integration-Test -depends Pack-Nuget, Create-ModuleZipForRemoting {
    pushd "$baseDir"
    $pesterDir = "$env:ChocolateyInstall\lib\Pester"
    if($testName){
        exec {."$pesterDir\tools\bin\Pester.bat" $baseDir/IntegrationTests -testName $testName}
    }
    else{
        exec {."$pesterDir\tools\bin\Pester.bat" $baseDir/IntegrationTests }
    }
    popd
}

Task Version-Module -description 'Stamps the psd1 with the version and last changeset SHA' {
    Get-ChildItem "$baseDir\**\*.psd1" | % {
       $path = $_
        (Get-Content $path) |
            % {$_ -replace "^ModuleVersion = '.*'`$", "ModuleVersion = '$version'" } | 
                % {$_ -replace "^PrivateData = '.*'`$", "PrivateData = '$changeset'" } | 
                    Set-Content $path
    }
    (Get-Content "$baseDir\BuildScripts\bootstrapper.ps1") |
        % {$_ -replace " -version .*`$", " -version $version`"" } | 
            Set-Content "$baseDir\BuildScripts\bootstrapper.ps1"
}

Task Clean-Artifacts {
    if (Test-Path "$baseDir\buildArtifacts") {
      Remove-Item "$baseDir\buildArtifacts" -Recurse -Force
    }
    mkdir "$baseDir\buildArtifacts"
}

Task Pack-Nuget -depends Clean-Artifacts -description 'Packs the modules and example packages' {
    if (Test-Path "$baseDir\buildPackages\*.nupkg") {
      Remove-Item "$baseDir\buildPackages\*.nupkg" -Force
    }

    PackDirectory "$baseDir\BuildPackages"
    PackDirectory "$baseDir\BuildScripts\nuget" -AddReleaseNotes
    Move-Item "$baseDir\BuildScripts\nuget\*.nupkg" "$basedir\buildArtifacts"
}

Task Package-DownloadZip -depends Clean-Artifacts {
    if (Test-Path "$basedir\BuildArtifacts\Boxstarter.*.zip") {
      Remove-Item "$basedir\BuildArtifacts\Boxstarter.*.zip" -Force
    }

    exec { ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\BuildArtifacts\Boxstarter.$version.zip" "$basedir\license.txt" }
    exec { ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\BuildArtifacts\Boxstarter.$version.zip" "$basedir\buildscripts\bootstrapper.ps1" }
    exec { ."$env:chocolateyInstall\bin\7za.exe" a -tzip "$basedir\BuildArtifacts\Boxstarter.$version.zip" "$basedir\buildscripts\Setup.bat" }
}

Task Deploy-DownloadZip -depends Package-DownloadZip {
    Remove-Item "$basedir\web\downloads" -Recurse -Force -ErrorAction SilentlyContinue
    mkdir "$basedir\web\downloads"
    Copy-Item "$basedir\BuildArtifacts\Boxstarter.$version.zip" "$basedir\web\downloads"
}

Task Push-Nuget -description 'Pushes the module to MyGet feed' {
    PushDirectory $baseDir\buildPackages
    PushDirectory $baseDir\buildArtifacts
}

Task Push-Chocolatey -description 'Pushes the module to Chocolatey feed' {
    exec { 
        Get-ChildItem "$baseDir\buildArtifacts\*.nupkg" | 
            % { cpush $_  }
    }
}

Task Push-Github {
    $headers = @{
        Authorization = 'Basic ' + [Convert]::ToBase64String(
            [Text.Encoding]::ASCII.GetBytes("mwrock:$($env:github_api)"));
    }

    $releaseNotes = Get-ReleaseNotes
    $postParams = ConvertTo-Json @{
        tag_name="v$version"
        target_commitish=$changeset
        name="v$version"
        body=$releaseNotes.DocumentElement.'#text'
    } -Compress

    $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/mwrock/boxstarter/releases/latest" -Method GET -Headers $headers
    if($latest.tag_name -ne "v$version"){
        write-host "Creating release"
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/mwrock/boxstarter/releases" -Method POST -Body $postParams -Headers $headers
        $uploadUrl = $response.upload_url.replace("{?name,label}","?name=boxstarter.$version.zip")
    }
    else {
        $uploadUrl = $latest.upload_url.replace("{?name,label}","?name=boxstarter.$version.zip")
    }

    write-host "Uploading $basedir\BuildArtifacts\Boxstarter.$version.zip to $uploadUrl"
    try {
        Invoke-RestMethod -Uri $uploadUrl -Method POST -ContentType "application/zip" -InFile "$basedir\BuildArtifacts\Boxstarter.$version.zip" -Headers $headers
    }
    catch{
        write-host $_ | fl * -force
    }
}

task Update-Homepage {
     $versionPattern="[0-9]+(\.([0-9]+|\*)){1,3}"
     $filename = "$baseDir\web\App_Code\Helper.cshtml"
     (Get-Content $filename) | % {$_ -replace $versionPattern, ($version) } | Set-Content $filename
}

task Get-ClickOnceStats {
    $creds = Get-Credential
    mkdir "$basedir\sitelogs" -ErrorAction silentlycontinue
    pushd "$basedir\sitelogs"
    $ftpScript = @"
user $($creds.UserName) $($creds.GetNetworkCredential().Password)
cd LogFiles/http/RawLogs
mget *
bye
"@
    $ftpScript | ftp -i -n $ftpHost
    if(!(Test-Path $env:ChocolateyInstall\lib\logparser*)) { cinst logparser -y }
    $logParser = "${env:programFiles(x86)}\Log Parser 2.2\LogParser.exe"
    .$logparser -i:w3c "SELECT Date, EXTRACT_VALUE(cs-uri-query,'package') as package, COUNT(*) as count FROM * where cs-uri-stem = '/launch/Boxstarter.WebLaunch.Application' Group by Date, package Order by Date, package" -rtp:-1
    popd
    del "$basedir\sitelogs" -Recurse -Force
}

task Install-MSBuild {
    if(!(Test-Path "$env:ProgramFiles\MSBuild\12.0\Bin\msbuild.exe")) { cinst microsoft-build-tools -y }
}

task Install-Win8SDK {
    if(!(Test-Path "$env:ProgramFiles\Windows Kits\8.1\bin\x64\signtool.exe")) { cinst windows-sdk-8.1 -y }
}

task Install-WebAppTargets {
    if(!(Test-Path "$env:ChocolateyInstall\lib\MSBuild.Microsoft.VisualStudio.Web.targets.12.0.4\tools\VSToolsPath\WebApplications\Microsoft.WebApplication.targets")) { 
        cinst MSBuild.Microsoft.VisualStudio.Web.targets -source http://packages.nuget.org/v1/FeedService.svc/ -version '12.0.4' -y
    }
}

task Install-WebDeploy {
    if(!(Test-Path "$env:ProgramW6432\IIS\Microsoft Web Deploy V3")) { cinst webdeploy -y }
}

task Install-ChocoLib {
    exec { .$nugetExe install chocolatey.lib -Version 0.9.10-beta-20151210 -Pre -OutputDirectory $basedir\Boxstarter.Chocolatey\ }
    exec { .$nugetExe install log4net -Version 2.0.3 -OutputDirectory $basedir\Boxstarter.Chocolatey\ }
    MkDir $basedir\Boxstarter.Chocolatey\chocolatey -ErrorAction SilentlyContinue
    Copy-Item $basedir\Boxstarter.Chocolatey\log4net.2.0.3\lib\net40-full\* $basedir\Boxstarter.Chocolatey\chocolatey
    Copy-Item $basedir\Boxstarter.Chocolatey\chocolatey.lib.0.9.10-beta-20151210\lib\* $basedir\Boxstarter.Chocolatey\chocolatey
    Remove-Item $basedir\Boxstarter.Chocolatey\log4net.2.0.3 -Recurse -Force
    Remove-Item $basedir\Boxstarter.Chocolatey\chocolatey.lib.0.9.10-beta-20151210 -Recurse -Force
}

function PackDirectory($path, [switch]$AddReleaseNotes){
    exec { 
        $releaseNotes = Get-ReleaseNotes
        Get-ChildItem $path -Recurse -include *.nuspec | 
            % { 
                 if($AddReleaseNotes) {
                   [xml]$nuspec = Get-Content $_
                   $oldReleaseNotes = $nuspec.package.metadata.ChildNodes| ? { $_.Name -eq 'releaseNotes' }
                   $newReleaseNotes = $nuspec.ImportNode($releaseNotes.DocumentElement, $true)
                   $nuspec.package.metadata.ReplaceChild($newReleaseNotes, $oldReleaseNotes) | Out-Null 
                   $nuspec.Save($_)
                 }
                 .$nugetExe pack $_ -OutputDirectory $path -NoPackageAnalysis -version $version 
              }
    }
}

function Get-ReleaseNotes {
    [xml](Get-Content "$baseDir\BuildScripts\releaseNotes.xml")
}

function PushDirectory($path){
    exec { 
        Get-ChildItem "$path\*.nupkg" | 
            % { cpush $_ -source "http://www.myget.org/F/boxstarter/api/v2/package" }
    }
}

# Borrowed from Luis Rocha's Blog (http://www.luisrocha.net/2009/11/setting-assembly-version-with-windows.html)
function Update-AssemblyInfoFiles ([string] $version, [string] $commit) {
    $assemblyVersionPattern = 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
    $fileVersionPattern = 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
    $fileCommitPattern = 'AssemblyTrademark\("([a-f0-9]{40})?"\)'
    $assemblyVersion = 'AssemblyVersion("' + $version + '")';
    $fileVersion = 'AssemblyFileVersion("' + $version + '")';
    $commitVersion = 'AssemblyTrademark("' + $commit + '")';

    Get-ChildItem -path $baseDir -r -filter AssemblyInfo.cs | ForEach-Object {
        $filename = $_.Directory.ToString() + '\' + $_.Name
        $filename + ' -> ' + $version
        
        # If you are using a source control that requires to check-out files before 
        # modifying them, make sure to check-out the file here.
        # For example, TFS will require the following command:
        # tf checkout $filename
    
        (Get-Content $filename) | ForEach-Object {
            % {$_ -replace $assemblyVersionPattern, $assemblyVersion } |
            % {$_ -replace $fileVersionPattern, $fileVersion } |
            % {$_ -replace $fileCommitPattern, $commitVersion }
        } | Set-Content $filename
    }
}
