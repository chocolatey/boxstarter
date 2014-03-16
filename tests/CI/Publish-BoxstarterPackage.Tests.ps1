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
    Mock Invoke-BoxstarterBuild
    Mock Get-BoxstarterPackages {
        New-Object PSObject -Property @{
            Id = $pkgName
            Version = "2.0.0.0"
            PublishedVersion="1.0.0.0"
            Feed=$feed
        }
    }
}