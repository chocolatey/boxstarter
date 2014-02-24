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

Describe "Set-BoxstarterPackageNugetFeed" {
    $Boxstarter.LocalRepo=(Get-PSDrive TestDrive).Root
    $Boxstarter.SuppressLogging=$true

    Context "package has a feed" {
        New-BoxstarterPackage -name package1
        [Uri]$feed="http://myfeed"
        Set-BoxstarterPackageNugetFeed -PackageName package1 -NugetFeed $feed

        $result = Get-BoxstarterPackageNugetFeed -PackageName package1

        it "should return the feed that was set" {
            $result | should be $feed
        }
    }

    Context "package has no feed" {
        New-BoxstarterPackage -name package1
        [Uri]$feed="http://default"
        Set-BoxstarterDeployOptions -DefaultNugetFeed $feed
        
        $result = Get-BoxstarterPackageNugetFeed -PackageName package1

        it "should return the default feed" {
            $result | should be $feed
        }
    }

    Context "setting a feed for an nonexistent package" {
        [Uri]$feed="http://default"
        
        try { 
            Set-BoxstarterPackageNugetFeed -PackageName package1 -NugetFeed $feed
        }
        catch{
            $err=$_
        }

        it "should return an error" {
            $err.CategoryInfo.Reason | should be "InvalidOperationException"
        }
    }

    Context "package has a feed and the feed is later removed" {
        New-BoxstarterPackage -name package1
        [Uri]$feed="http://myfeed"
        [Uri]$defaultfeed="http://default"
        Set-BoxstarterDeployOptions -DefaultNugetFeed $defaultfeed
        Set-BoxstarterPackageNugetFeed -PackageName package1 -NugetFeed $feed

        $result1 = Get-BoxstarterPackageNugetFeed -PackageName package1

        Remove-BoxstarterPackageNugetFeed -PackageName package1
        $result2 = Get-BoxstarterPackageNugetFeed -PackageName package1

        it "should return the feed that was set before removal" {
            $result1 | should be $feed
        }
        it "should return the default feed after removal" {
            $result2 | should be $defaultfeed
        }
    }
}