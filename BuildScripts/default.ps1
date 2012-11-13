$psake.use_exit_on_error = $true
properties {
    $baseDir = $psake.build_script_dir
    $version = git describe --abbrev=0 --tags
    $version += "."
    $version += (git log $($version + '..') --pretty=oneline | measure-object).Count
    $nugetExe = "$env:ChocolateyInstall\ChocolateyInstall\nuget"
}

Task default -depends Build
Task Build -depends Package, Push-Nuget -description 'Versions, packages and pushes to Myget'
Task Package -depends Version-Module, Pack-Nuget, Unversion-Module -description 'Versions the psm1 and packs the module and example package'

Task Version-Module -description 'Stamps the psm1 with the version and last changeset SHA' {
    $v = git describe --abbrev=0 --tags
    $changeset=(git log -1 $($v + '..') --pretty=format:%H)
    (Get-Content "$baseDir\boxstarter.psm1") | % {$_ -replace "\`$version\`$", "$version" } | % {$_ -replace "\`$sha\`$", "$changeset" } | Set-Content "$baseDir\boxstarter.psm1"
}

Task Unversion-Module -description 'Removes the versioning from the psm1' {
    $v = git describe --abbrev=0 --tags
    $changeset=(git log -1 $($v + '..') --pretty=format:%H)
    (Get-Content "$baseDir\boxstarter.psm1") | % {$_ -replace "$version", "`$version`$" } | % {$_ -replace "$changeset", "`$sha`$" } | Set-Content "$baseDir\boxstarter.psm1"
}

Task Pack-Nuget -description 'Packs the module and example package' {
    if (Test-Path "$baseDir\build") {
      Remove-Item "$baseDir\build" -Recurse -Force
    }
    exec { .$nugetExe pack "$baseDir\BuildPackages\example\example.nuspec" -OutputDirectory "$baseDir\BuildPackages" -NoPackageAnalysis -version $version }
    mkdir "$baseDir\build"
    exec { .$nugetExe pack "$baseDir\nuget\boxstarter.nuspec" -OutputDirectory "$baseDir\buildArtifacts" -NoPackageAnalysis -version $version }
}

Task Push-Nuget -description 'Pushes the module to Myget work feed' {
    $pkg = Get-Item -path $baseDir\build\boxstarter.*.*.*.nupkg
    exec { cpush $pkg.FullName -source "http://www.myget.org/F/work/api/v2/package" }
}