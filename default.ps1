$psake.use_exit_on_error = $true
properties {
    $baseDir = $psake.build_script_dir
    $version = git describe --abbrev=0 --tags
    $version = (git log $($version + '..') --pretty=oneline | measure-object).Count
}

Task default -depends Build
Task Build -depends Package
Task Package -depends Version-Module, Pack-Nuget, Unversion-Module, Push-Nuget

Task Version-Module{
    $v = git describe --abbrev=0 --tags
    $changeset=(git log -1 $($v + '..') --pretty=format:%H)
    (Get-Content "$baseDir\boxstarter.psm1") | % {$_ -replace "\`$version\`$", "$version" } | % {$_ -replace "\`$sha\`$", "$changeset" } | Set-Content "$baseDir\boxstarter.psm1"
}

Task Unversion-Module{
    $v = git describe --abbrev=0 --tags
    $changeset=(git log -1 $($v + '..') --pretty=format:%H)
    (Get-Content "$baseDir\boxstarter.psm1") | % {$_ -replace "$version", "`$version`$" } | % {$_ -replace "$changeset", "`$sha`$" } | Set-Content "$baseDir\boxstarter.psm1"
}

Task Pack-Nuget {
    if (Test-Path "$baseDir\build") {
      Remove-Item "$baseDir\build" -Recurse -Force
    }
    exec { cpack "$baseDir\BuildPackages\example\example.nuspec" -OutputDirectory "$baseDir\BuildPackages" -version $version }
    mkdir "$baseDir\build"
    exec { cpack "$baseDir\nuget\boxstarter.nuspec" -OutputDirectory "$baseDir\build" -version $version }
}

Task Push-Nuget {
    $pkg = Get-Item -path $baseDir\build\boxstarter.*.*.*.nupkg
    exec { cpush $pkg.FullName -source http://www.myget.org/F/work/api/v2/package }
}