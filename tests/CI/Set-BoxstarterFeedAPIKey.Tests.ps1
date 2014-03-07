
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

Describe "Set-BoxstarterFeedAPIKey" {
    $Boxstarter.LocalRepo=(Get-PSDrive TestDrive).Root
    $Boxstarter.SuppressLogging=$true

    Context "Feed has a key" {
        $key = [GUID]::NewGuid()
        [Uri]$feed="http://myfeed"
        Set-BoxstarterFeedAPIKey -NugetFeed $feed -APIKey $key

        $result = Get-BoxstarterFeedAPIKey -NugetFeed $feed

        it "should return the key that was set" {
            $result | should be $key
        }
    }

    Context "feed has no key" {
        $key = [GUID]::NewGuid()
        [Uri]$feed="http://default"
        
        $result = Get-BoxstarterFeedAPIKey -NugetFeed $feed

        it "should return null" {
            $result | should be $null
        }
    }
}