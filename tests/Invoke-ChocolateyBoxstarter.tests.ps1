$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.chocolatey){Remove-Module boxstarter.chocolatey}

Describe "Invoke-ChocolateyBoxstarter via bootstrapper.bat (end to end)" {
    ."$here\..\build.bat" Pack-Nuget
    $testRoot = (Get-PSDrive TestDrive).Root
    mkdir "$testRoot\Repo" -ErrorAction SilentlyContinue | Out-Null
    Copy-Item $here\..\BuildArtifacts\test-package.*.nupkg "$testRoot\Repo"

    Context "When installing a local package" {
        remove-Item "$env:ChocolateyInstall\lib\test-package.*" -force -recurse
        Add-Content "$env:ChocolateyInstall\ChocolateyInstall\ChocolateyInstall.log" -Value "______ test-package v1.0.0 ______" -force

        ."$here\..\boxstarter.bat" test-package -LocalRepo "$testRoot\Repo"

        it "should save boxstarter package to chocolatey lib folder" {
            Test-Path "$env:ChocolateyInstall\lib\test-package.*" | Should Be $true
        }
        it "should have cleared previous logs" {
            $installLines = get-content "$env:ChocolateyInstall\ChocolateyInstall\ChocolateyInstall.log" | ? { $_ -eq "______ test-package v1.0.0 ______" } 
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
Resolve-Path $here\..\boxstarter.chocolatey\*.ps1 | 
    % { . $_.ProviderPath }    
$Boxstarter.SuppressLogging=$true
$Boxstarter.BaseDir= (split-path -parent $here)

Describe "Invoke-ChocolateyBoxstarter" {
    Context "When not invoked via boxstarter" {
        $global:BoxstarterStarted=$false
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
        $global:BoxstarterStarted=$true
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
}
