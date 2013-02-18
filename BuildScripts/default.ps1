$psake.use_exit_on_error = $true
properties {
    $baseDir = (Split-Path -parent $psake.build_script_dir)
    $versionTag = git describe --abbrev=0 --tags
    $version = $versionTag + "."
    $version += (git log $($version + '..') --pretty=oneline | measure-object).Count
    $changeset=(git log -1 $($versionTag + '..') --pretty=format:%H)
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
    Set-Version "$baseDir\boxstarter.Common\boxstarter.Common.psd1"
    Set-Version "$baseDir\boxstarter.WinConfig\boxstarter.WinConfig.psd1"
    Set-Version "$baseDir\boxstarter.bootstrapper\boxstarter.bootstrapper.psd1"
    Set-Version "$baseDir\boxstarter.Chocolatey\boxstarter.Chocolatey.psd1"
}

Task Pack-Nuget -description 'Packs the modules and example packages' {
    if (Test-Path "$baseDir\buildArtifacts") {
      Remove-Item "$baseDir\buildArtifacts" -Recurse -Force
    }
    if (Test-Path "$baseDir\buildPackages\*.nupkg") {
      Remove-Item "$baseDir\buildPackages\*.nupkg" -Force
    }
    mkdir "$baseDir\buildArtifacts"
    exec { .$nugetExe pack "$baseDir\BuildPackages\example\example.nuspec" -OutputDirectory "$baseDir\BuildPackages" -NoPackageAnalysis -version $version }
    exec { .$nugetExe pack "$baseDir\BuildPackages\example-light\example-light.nuspec" -OutputDirectory "$baseDir\BuildPackages" -NoPackageAnalysis -version $version }    
    exec { .$nugetExe pack "$baseDir\BuildPackages\test-package\test-package.nuspec" -OutputDirectory "$baseDir\buildArtifacts" -NoPackageAnalysis }    
    #exec { .$nugetExe pack "$baseDir\helpers\boxstarter.helpers.nuspec" -OutputDirectory "$baseDir\buildArtifacts" -NoPackageAnalysis -version $version }
    #exec { .$nugetExe pack "$baseDir\nuget\boxstarter.nuspec" -OutputDirectory "$baseDir\buildArtifacts" -NoPackageAnalysis -version $version }
}

Task Push-Nuget -description 'Pushes the module to Myget feed' {
    $pkg = Get-Item -path $baseDir\buildPackages\example.*.*.*.nupkg
    exec { cpush $pkg.FullName -source "http://www.myget.org/F/boxstarter/api/v2/package" }
    $pkg = Get-Item -path $baseDir\buildPackages\example-light.*.*.*.nupkg   
    exec { cpush $pkg.FullName -source "http://www.myget.org/F/boxstarter/api/v2/package" }
    $pkg = Get-Item -path $baseDir\buildArtifacts\boxstarter.*.*.*.nupkg   
    exec { cpush $pkg.FullName -source "http://www.myget.org/F/boxstarter/api/v2/package" }
    $pkg = Get-Item -path $baseDir\buildArtifacts\boxstarter.helpers.*.*.*.nupkg   
    exec { cpush $pkg.FullName -source "http://www.myget.org/F/boxstarter/api/v2/package" }
}

Task Push-Chocolatey -description 'Pushes the module to Chocolatey feed' {
    $pkg = Get-Item -path $baseDir\buildArtifacts\boxstarter.0.*.*.nupkg   
    exec { cpush $pkg.FullName }
    $pkg = Get-Item -path $baseDir\buildArtifacts\boxstarter.helpers.*.*.*.nupkg   
    exec { cpush $pkg.FullName }
}

function Set-Version($path){
    (Get-Content $path) | % {$_ -replace "^ModuleVersion = '.*'`$", "ModuleVersion = '$version'" } | % {$_ -replace "^PrivateData = '.*'`$", "PrivateData = '$changeset'" } | Set-Content $path   
}