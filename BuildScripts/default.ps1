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
Task Build -depends Test, Package
Task Deploy -depends Test, Package, Push-Nuget -description 'Versions, packages and pushes to Myget'
Task Package -depends Version-Module, Pack-Nuget -description 'Versions the psd1 and packs the module and example package'

Task Test {
    pushd "$baseDir"
    exec {."$env:ChocolateyInstall\lib\Pester.1.2.1\tools\bin\Pester.bat" $baseDir/Tests -DisableLegacyExpectations}
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

Task Pack-Nuget -description 'Packs the modules and example packages' {
    if (Test-Path "$baseDir\buildArtifacts") {
      Remove-Item "$baseDir\buildArtifacts" -Recurse -Force
    }
    if (Test-Path "$baseDir\buildPackages\*.nupkg") {
      Remove-Item "$baseDir\buildPackages\*.nupkg" -Force
    }
    mkdir "$baseDir\buildArtifacts"

    PackDirectory "$baseDir\BuildPackages"
    PackDirectory "$baseDir\BuildScripts\nuget"
    Move-Item "$baseDir\BuildScripts\nuget\*.nupkg" "$basedir\buildArtifacts"

    exec { 7za a -tzip "$basedir\BuildArtifacts\Boxstarter.$version.zip" "$basedir\boxstarter.*" }
    exec { 7za a -tzip "$basedir\BuildArtifacts\Boxstarter.$version.zip" "$basedir\license.txt" }
    exec { 7za a -tzip "$basedir\BuildArtifacts\Boxstarter.$version.zip" "$basedir\BuildScripts\Setup.ps1" }
    exec { 7za a -tzip "$basedir\BuildArtifacts\Boxstarter.$version.zip" "$basedir\Setup.bat" }
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