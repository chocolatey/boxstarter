$psake.use_exit_on_error = $true
properties {
    $baseDir = (Split-Path -parent $psake.build_script_dir)
    if(Get-Command Git -ErrorAction SilentlyContinue) {
        $versionTag = git describe --abbrev=0 --tags
        $version = $versionTag + "."
        $version += (git log $($version + '..') --pretty=oneline | measure-object).Count
        $changeset=(git log -1 $($versionTag + '..') --pretty=format:%H)
    }
    else {
        $version="1.0.0"
    }
    $nugetExe = "$env:ChocolateyInstall\ChocolateyInstall\nuget"
}

Task default -depends Build
Task Build -depends Build-Clickonce, Test, Package
Task Deploy -depends Build, Deploy-DownloadZip, Publish-Clickonce, Update-Homepage, Push-Nuget -description 'Versions, packages and pushes to Myget'
Task Package -depends Clean-Artifacts, Version-Module, Pack-Nuget, Package-DownloadZip -description 'Versions the psd1 and packs the module and example package'

task Build-ClickOnce {
    Update-AssemblyInfoFiles $version $changeset
    exec { msbuild "$baseDir\Boxstarter.ClickOnce\Boxstarter.WebLaunch.csproj" /t:Clean /v:quiet }
    exec { msbuild "$baseDir\Boxstarter.ClickOnce\Boxstarter.WebLaunch.csproj" /t:Build /v:quiet }
}

task Publish-ClickOnce {
    exec { msbuild "$baseDir\Boxstarter.ClickOnce\Boxstarter.WebLaunch.csproj" /t:Publish /v:quiet /p:ApplicationVersion="$version.0" }
    Remove-Item "$basedir\public\Launch" -Recurse -Force -ErrorAction SilentlyContinue
    MkDir "$basedir\public\Launch"
    Copy-Item "$basedir\Boxstarter.Clickonce\bin\Debug\App.Publish\Application Files" "$basedir\public\Launch" -Recurse -Force
    Copy-Item "$basedir\Boxstarter.Clickonce\bin\Debug\App.Publish\Boxstarter.WebLaunch.Application" "$basedir\public\Launch"
}

Task Test {
    pushd "$baseDir"
    $pesterDir = (dir $env:ChocolateyInstall\lib\Pester*)
    if($pesterDir.length -gt 0) {$pesterDir = $pesterDir[-1]}
    exec {."$pesterDir\tools\bin\Pester.bat" $baseDir/Tests }
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
}

Task Clean-Artifacts {
    if (Test-Path "$baseDir\buildArtifacts") {
      Remove-Item "$baseDir\buildArtifacts" -Recurse -Force
    }
}

Task Create-ArtifactsDir {
    if(!(Test-Path "$baseDir\buildArtifacts")){
        mkdir "$baseDir\buildArtifacts"
    }
}

Task Pack-Nuget -depends Create-ArtifactsDir -description 'Packs the modules and example packages' {
    if (Test-Path "$baseDir\buildPackages\*.nupkg") {
      Remove-Item "$baseDir\buildPackages\*.nupkg" -Force
    }

    PackDirectory "$baseDir\BuildPackages"
    PackDirectory "$baseDir\BuildScripts\nuget"
    Move-Item "$baseDir\BuildScripts\nuget\*.nupkg" "$basedir\buildArtifacts"
}

Task Package-DownloadZip -depends Create-ArtifactsDir {
    if (Test-Path "$basedir\BuildArtifacts\Boxstarter.*.zip") {
      Remove-Item "$basedir\BuildArtifacts\Boxstarter.*.zip" -Force
    }

    exec { 7za a -tzip "$basedir\BuildArtifacts\Boxstarter.$version.zip" "$basedir\boxstarter.common" }
    exec { 7za a -tzip "$basedir\BuildArtifacts\Boxstarter.$version.zip" "$basedir\boxstarter.WinConfig" }
    exec { 7za a -tzip "$basedir\BuildArtifacts\Boxstarter.$version.zip" "$basedir\boxstarter.bootstrapper" }
    exec { 7za a -tzip "$basedir\BuildArtifacts\Boxstarter.$version.zip" "$basedir\boxstarter.chocolatey" }
    exec { 7za a -tzip "$basedir\BuildArtifacts\Boxstarter.$version.zip" "$basedir\license.txt" }
    exec { 7za a -tzip "$basedir\BuildArtifacts\Boxstarter.$version.zip" "$basedir\BuildScripts\Setup.ps1" }
    exec { 7za a -tzip "$basedir\BuildArtifacts\Boxstarter.$version.zip" "$basedir\Setup.bat" }
}

Task Deploy-DownloadZip -depends Package-DownloadZip {
    Remove-Item "$basedir\public\downloads" -Recurse -Force -ErrorAction SilentlyContinue
    mkdir "$basedir\public\downloads"
    Copy-Item "$basedir\BuildArtifacts\Boxstarter.$version.zip" "$basedir\public\downloads"
}

Task Push-Nuget -description 'Pushes the module to Myget feed' {
    PushDirectory $baseDir\buildPackages
    PushDirectory $baseDir\buildArtifacts
}

Task Push-Chocolatey -description 'Pushes the module to Chocolatey feed' {
    exec { 
        Get-ChildItem "$baseDir\buildArtifacts\*.nupkg" | 
            % { cpush $_  }
    }
}

function PackDirectory($path){
    exec { 
        Get-ChildItem $path -Recurse -include *.nuspec | 
            % { .$nugetExe pack $_ -OutputDirectory $path -NoPackageAnalysis -version $version }
    }
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

task Update-Homepage {
     $downloadUrl="Boxstarter.$version.zip"
     $downloadButtonUrlPatern="Boxstarter\.[0-9]+(\.([0-9]+|\*)){1,3}\.zip"
     $downloadLinkTextPattern="V[0-9]+(\.([0-9]+|\*)){1,3}"
     $filename = "$baseDir\public\index.html"
     (Get-Content $filename) | % {$_ -replace $downloadButtonUrlPatern, $downloadUrl } | % {$_ -replace $downloadLinkTextPattern, ("v"+$version) } | Set-Content $filename
}