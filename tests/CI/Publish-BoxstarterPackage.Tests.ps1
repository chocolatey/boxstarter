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

Describe "Publish-BoxstarterPackage" {
    $Boxstarter.LocalRepo=(Get-PSDrive TestDrive).Root
    $Boxstarter.SuppressLogging=$true
    $ProgressPreference="SilentlyContinue"
    $pkgName="package1"
    [Uri]$feed="http://myfeed"
    Mock Get-BoxstarterPackages {
        New-Object PSObject -Property @{
            Id = $pkgName
            Version = "2.0.0.0"
            PublishedVersion="1.0.0.0"
            Feed=$feed
        }
    }

    Context "When successfully publishing a package" {
        
        $result = Publish-BoxstarterPackage "package1"

        it "Should return the name of the published package" {
            $result.Package | should be $pkgName 
        }
        it "Should return the feed of the published package" {
            $result.Feed | should be $feed 
        }
        it "Should have matching repo and published versions" {
            $result.PulishedVersion | should be 2.0.0.0
        }
    }
}