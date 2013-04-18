$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.chocolatey){Remove-Module boxstarter.chocolatey}

Describe "Invoke-ChocolateyBoxstarter via bootstrapper.bat (end to end)" {
    ."$here\..\build.bat" Pack-Nuget
    $testRoot = (Get-PSDrive TestDrive).Root
    mkdir "$testRoot\Repo" -ErrorAction SilentlyContinue | Out-Null
    Copy-Item $here\..\BuildPackages\test-package.*.nupkg "$testRoot\Repo"

    Context "When installing a local package" {
        remove-Item "$env:ChocolateyInstall\lib\test-package.*" -force -recurse
        Add-Content "$env:ChocolateyInstall\ChocolateyInstall\ChocolateyInstall.log" -Value "______ test-package v1.0.0 ______" -force

        ."$here\..\boxstarter.bat" test-package -LocalRepo "$testRoot\Repo" -DisableReboots

        it "should save boxstarter package to chocolatey lib folder" {
            Test-Path "$env:ChocolateyInstall\lib\test-package.*" | Should Be $true
        }
        it "should have cleared previous logs" {
            $installLines = get-content "$env:ChocolateyInstall\ChocolateyInstall\Install.log" | ? { $_ -like "Successfully installed 'test-package*" } 
            $installLines.Count | Should Be 1
        }          
    }
}

Resolve-Path $here\..\boxstarter.common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\boxstarter.winconfig\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\boxstarter.bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
$Boxstarter.BaseDir=(split-path -parent $here)
$Boxstarter.SuppressLogging=$true
Resolve-Path $here\..\boxstarter.chocolatey\*.ps1 | 
    % { . $_.ProviderPath }    
Intercept-Chocolatey

Describe "Invoke-ChocolateyBoxstarter" {
    Context "When not invoked via boxstarter" {
        $Boxstarter.ScriptToCall=$null
        Mock Invoke-Boxstarter
        Mock Chocolatey
        Mock Check-Chocolatey

        Invoke-ChocolateyBoxstarter package

        it "should Call Boxstarter" {
            Assert-MockCalled Invoke-Boxstarter
        }
        it "should not call chocolatey" {
            Assert-MockCalled chocolatey -times 0
        }          
    }

    Context "When invoked via boxstarter" {
        $Boxstarter.ScriptToCall="return"
        Mock Invoke-Boxstarter
        Mock Chocolatey
        Mock Check-Chocolatey

        Invoke-ChocolateyBoxstarter package

        it "should not Call Boxstarter" {
            Assert-MockCalled Invoke-Boxstarter -times 0
        }
        it "should call chocolatey" {
            Assert-MockCalled chocolatey
        }          
    }

    Context "When Setting a LocalRepo on $Boxstarter and not the commandLine" {
        $Boxstarter.ScriptToCall="return"
        $Boxstarter.LocalRepo="myrepo"
        Mock Invoke-Boxstarter
        Mock Chocolatey
        Mock Check-Chocolatey

        Invoke-ChocolateyBoxstarter package

        it "should use Boxstarter.Localrepo value" {
            $Boxstarter.LocalRepo | should be "myrepo"
        }
    }

    Context "When Setting a LocalRepo on the commandLine" {
        $Boxstarter.ScriptToCall="return"
        $Boxstarter.LocalRepo="myrepo"
        Mock Invoke-Boxstarter
        Mock Chocolatey
        Mock Check-Chocolatey

        Invoke-ChocolateyBoxstarter package -Localrepo "c:\anotherRepo"

        it "should use command line value" {
            $Boxstarter.LocalRepo | should be "c:\anotherRepo"
        }
    }
}
