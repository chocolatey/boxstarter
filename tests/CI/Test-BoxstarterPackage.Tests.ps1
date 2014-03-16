$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.CI){Remove-Module boxstarter.CI}
Resolve-Path $here\..\..\Boxstarter.Common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Chocolatey\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.CI\*.ps1 | 
    ? { $_.Path -like "*-*" } | 
    % { . $_.ProviderPath }

Describe "Test-BoxstarterPackage" {
    $Boxstarter.LocalRepo=(Get-PSDrive TestDrive).Root
    $Boxstarter.SuppressLogging=$true
    $ProgressPreference="SilentlyContinue"
    $pkgName1="package1"
    $pkgName2="package2"
    Mock Invoke-BoxstarterBuild
    [Uri]$feed="http://myfeed"
    Mock Get-BoxstarterPackages {
        New-Object PSObject -Property @{
            Id = $pkgName1
            Version = "2.0.0.0"
            PublishedVersion="1.0.0.0"
            Feed=$feed
        }
        New-Object PSObject -Property @{
            Id = $pkgName2
            Version = "2.0.0.0"
            PublishedVersion="2.0.0.0"
            Feed=$feed
        }
    }

    Context "when testing a package ahead of the published version" {
        Set-BoxstarterDeployOptions -DeploymentTargetUserName "user" -DeploymentTargetPassword "pass" -DeploymentTargetNames "target1"
        Mock Install-BoxstarterPackage {
            @{
                Completed=$true
                Errors=@()
            }
        }

        $results = Test-BoxstarterPackage $pkgName1

        it "Will Build package" {
            Assert-MockCalled Invoke-BoxstarterBuild
        }
        it "will return a succeeded result" {
            $results.Status | should be "Passed"
        }
    }

    Context "when explicitly testing a package with a repo version equal to the published version" {
        Set-BoxstarterDeployOptions -DeploymentTargetUserName "user" -DeploymentTargetPassword "pass" -DeploymentTargetNames "target1"
        Mock Install-BoxstarterPackage {
            @{
                Completed=$true
                Errors=@()
            }
        }

        $results = Test-BoxstarterPackage $pkgName2

        it "Will Build package" {
            Assert-MockCalled Invoke-BoxstarterBuild
        }
    }

    Context "when a package test fails" {
        Set-BoxstarterDeployOptions -DeploymentTargetUserName "user" -DeploymentTargetPassword "pass" -DeploymentTargetNames "target1"
        Mock Install-BoxstarterPackage {
            @{
                Completed=$false
                Errors=@()
            }
        }

        $results = Test-BoxstarterPackage $pkgName1

        it "Will Build package" {
            Assert-MockCalled Invoke-BoxstarterBuild
        }
        it "will return a failed result" {
            $results.Status | should be "Failed"
        }
    }

    Context "testing all repo packages" {
        Set-BoxstarterDeployOptions -DeploymentTargetUserName "user" -DeploymentTargetPassword "pass" -DeploymentTargetNames "target1"
        Mock Install-BoxstarterPackage {
            @{
                Completed=$true
                Errors=@()
            }
        } -ParameterFilter { $ComputerName -eq "target1" }

        $results = Test-BoxstarterPackage

        it "should return 2 results" {
            $results.Count | should be 2
        }
        it "Will return the names of both packages in the order retuned from Get-BoxstarterPackages" {
            $results[0].Package | should be $pkgName1
            $results[1].Package | should be $pkgName2
        }
        it "will ony test the changed package" {
            $results[0].Status | should be "Passed"
            $results[1].Status | should be "Skipped"
        }
    }
}