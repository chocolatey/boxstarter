$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter){Remove-Module boxstarter}
."$here\..\build.bat" Pack-Nuget
Copy-Item $here\..\BuildArtifacts\Boxstarter.Helpers.*.nupkg $here
Copy-Item $here\..\BuildPackages\test-package.*.nupkg $here

Describe "Invoke-Boxstarter" {
    Context "When installing a local package" {
        remove-Item "$env:ChocolateyInstall\lib\test-package.*" -force -recurse
        remove-Item "$env:ChocolateyInstall\lib\boxstarter.helpers.*" -force -recurse

        ."$here\..\boxstarter.bat" test-package $here

        it "should save boxstarter package to chocolatey lib folder" {
            (Test-Path "$env:ChocolateyInstall\lib\test-package.*").Should.Be($true)
        }
        it "should save helper package to chocolatey lib folder" {
            (Test-Path "$env:ChocolateyInstall\lib\boxstarter.helpers.*").Should.Be($true)
        }        
    }
    remove-Item "$here\*.nupkg" -force
}