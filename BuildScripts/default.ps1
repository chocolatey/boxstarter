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
Task Build -depends Package, Push-Nuget -description 'Versions, packages and pushes to Myget'
Task Package -depends Version-Module, Pack-Nuget, Unversion-Module -description 'Versions the psm1 and packs the module and example package'

Task Version-Module -description 'Stamps the psm1 with the version and last changeset SHA' {
    (Get-Content "$baseDir\Helpers\boxstarter.helpers.psm1") | % {$_ -replace "\`$version\`$", "$version" } | % {$_ -replace "\`$sha\`$", "$changeset" } | Set-Content "$baseDir\helpers\boxstarter.helpers.psm1"
    (Get-Content "$baseDir\bootstrapper\boxstarter.psm1") | % {$_ -replace "\`$version\`$", "$version" } | % {$_ -replace "\`$sha\`$", "$changeset" } | Set-Content "$baseDir\bootstrapper\boxstarter.psm1"    
}

Task Unversion-Module -description 'Removes the versioning from the psm1' {
    (Get-Content "$baseDir\helpers\boxstarter.helpers.psm1") | % {$_ -replace "$version", "`$version`$" } | % {$_ -replace "$changeset", "`$sha`$" } | Set-Content "$baseDir\helpers\boxstarter.helpers.psm1"
    (Get-Content "$baseDir\bootstrapper\boxstarter.psm1") | % {$_ -replace "$version", "`$version`$" } | % {$_ -replace "$changeset", "`$sha`$" } | Set-Content "$baseDir\bootstrapper\boxstarter.psm1"
}

Task Pack-Nuget -description 'Packs the module and example package' {
    if (Test-Path "$baseDir\buildArtifacts") {
      Remove-Item "$baseDir\buildArtifacts" -Recurse -Force
    }
    if (Test-Path "$baseDir\buildPackages\example*.nupkg") {
      Remove-Item "$baseDir\buildPackages\example*.nupkg" -Force
    }
    exec { .$nugetExe pack "$baseDir\BuildPackages\example\example.nuspec" -OutputDirectory "$baseDir\BuildPackages" -NoPackageAnalysis -version $version }
    exec { .$nugetExe pack "$baseDir\BuildPackages\example-light\example-light.nuspec" -OutputDirectory "$baseDir\BuildPackages" -NoPackageAnalysis -version $version }    
    mkdir "$baseDir\buildArtifacts"
    exec { .$nugetExe pack "$baseDir\helpers\boxstarter.helpers.nuspec" -OutputDirectory "$baseDir\buildArtifacts" -NoPackageAnalysis -version $version }
    exec { .$nugetExe pack "$baseDir\boxstarter.nuspec" -OutputDirectory "$baseDir\buildArtifacts" -NoPackageAnalysis -version $version }
}

Task Push-Nuget -description 'Pushes the module to Myget feed' {
    $pkg = Get-Item -path $baseDir\buildPackages\example.*.*.*.nupkg
    exec { cpush $pkg.FullName -source "http://www.myget.org/F/boxstarter/api/v2/package" }
    $pkg = Get-Item -path $baseDir\buildPackages\example-light.*.*.*.nupkg   
    exec { cpush $pkg.FullName -source "http://www.myget.org/F/boxstarter/api/v2/package" }
}