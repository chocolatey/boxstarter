$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter){Remove-Module boxstarter}
."$here\..\build.bat" Pack-Nuget

Describe "Invoke-Boxstarter" {
    $testRoot = (Get-PSDrive TestDrive).Root
    mkdir "$testRoot\Repo" -ErrorAction ignore
    Copy-Item $here\..\BuildArtifacts\Boxstarter.Helpers.*.nupkg "$testRoot\Repo"
    Copy-Item $here\..\BuildArtifacts\test-package.*.nupkg "$testRoot\Repo"
    Context "When installing a local package" {
        remove-Item "$env:ChocolateyInstall\lib\test-package.*" -force -recurse
        remove-Item "$env:ChocolateyInstall\lib\boxstarter.helpers.*" -force -recurse
        Add-Content "$env:ChocolateyInstall\ChocolateyInstall\ChocolateyInstall.log" -Value "______ test-package v1.0.0 ______" -force

        ."$here\..\boxstarter.bat" test-package "$testRoot\Repo"

        it "should save boxstarter package to chocolatey lib folder" {
            (Test-Path "$env:ChocolateyInstall\lib\test-package.*").Should.Be($true)
        }
        it "should save helper package to chocolatey lib folder" {
            (Test-Path "$env:ChocolateyInstall\lib\boxstarter.helpers.*").Should.Be($true)
        }
        it "should have cleared previous logs" {
            $installLines = get-content "$env:ChocolateyInstall\ChocolateyInstall\ChocolateyInstall.log" | ? { $_ -eq "______ test-package v1.0.0 ______" } 
            $installLines.Should.Have_Count_Of(1)
        }          
    }
}