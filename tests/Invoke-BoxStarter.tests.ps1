$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter){Remove-Module boxstarter}
."$here\..\build.bat" Pack-Nuget
Move-Item $here\..\BuildArtifacts\Boxstarter.Helpers.*.nupkg $here

Describe "Invoke-Boxstarter" {
    Context "When installing a local package" {
        remove-Item "$env:ChocolateyInstall\lib\test-package.*" -force -recurse
        
        ."$here\..\boxstarter.bat" test-package

        it "should save package to chocolatey lib folder" {
            (Test-Path "$env:ChocolateyInstall\lib\test-package.*").Should.Be($true)
        }
        remove-Item "$here\*.nupkg" -force
    }
}