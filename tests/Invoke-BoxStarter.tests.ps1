$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter){Remove-Module boxstarter}
."$here\..\build.bat" Pack-Nuget

Describe "Invoke-Boxstarter via bootstrapper.bat (end to end)" {
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

Resolve-Path $here\..\bootstrapper\*.ps1 | 
    ? { -not ($_.ProviderPath.Contains("AdminProxy")) } |
    % { . $_.ProviderPath }

Describe "Invoke-Boxstarter" {
    Mock Check-Chocolatey
    Mock Chocolatey
    Mock Stop-Service
    Mock Start-Service
    Mock Set-Service
    $testRoot = (Get-PSDrive TestDrive).Root

    Context "When Configuration Service is installed" {
        Mock Get-Service {new-Object -TypeName PSObject -Property @{CanStop=$True}} -ParameterFilter {$include -eq "CCMEXEC"}

        Invoke-Boxstarter test-package "$testRoot\Repo"

        it "will stop ConfigurationService" {
            Assert-MockCalled Stop-Service -ParameterFilter {$name -eq "CCMEXEC"}
        }
        it "will start ConfigurationService" {
            Assert-MockCalled Start-Service -ParameterFilter {$name -eq "CCMEXEC"}
        }
    }

      Context "When Configuration Service is not installed" {
        Mock Get-Service {$false} -ParameterFilter {$include -eq "CCMEXEC"}

        Invoke-Boxstarter test-package "$testRoot\Repo"

        it "will stop just WUA" {
            Assert-MockCalled Stop-Service -ParameterFilter {$name -eq "wuauserv"}
        }
        it "will just start WUA" {
            Assert-MockCalled Start-Service -ParameterFilter {$name -eq "wuauserv"}
        }
    }

      Context "When An exception occurs in the install" {
        Mock Get-Service {new-Object -TypeName PSObject -Property @{CanStop=$True}} -ParameterFilter {$include -eq "CCMEXEC"}
        Mock Chocolatey {throw "error"}

        Invoke-Boxstarter test-package "$testRoot\Repo"

        it "will stop WUA" {
            Assert-MockCalled Stop-Service -ParameterFilter {$name -eq "wuauserv"}
        }
        it "will stop CCM" {
            Assert-MockCalled Stop-Service -ParameterFilter {$name -eq "CCMEXEC"}
        }
    }
  
}