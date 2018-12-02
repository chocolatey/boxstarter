
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(Get-Module Boxstarter.TestRunner){Remove-Module Boxstarter.TestRunner}
Resolve-Path $here\..\..\Boxstarter.Common\*.ps1 |
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Bootstrapper\*.ps1 |
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Chocolatey\*.ps1 |
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.TestRunner\*.ps1 |
    ? { $_.Path -like "*-*" } |
    % { . $_.ProviderPath }

Describe "Set-BoxstarterFeedAPIKey" {
    $Boxstarter.BaseDir=(Get-PSDrive TestDrive).Root
    $Boxstarter.LocalRepo=Join-Path $Boxstarter.BaseDir LocalRepo
    MKDIR $Boxstarter.LocalRepo | Out-Null
    $Boxstarter.SuppressLogging=$true

    Context "Feed has a key" {
        $key = [GUID]::NewGuid()
        [Uri]$feed="http://myfeed"
        Set-BoxstarterFeedAPIKey -NugetFeed $feed -APIKey $key

        $result = Get-BoxstarterFeedAPIKey -NugetFeed $feed

        it "should return the key that was set" {
            $key | should be $result
        }
    }

   Context "When secrets keys are in the default localrepo and not the localrepo" {
        $Boxstarter.LocalRepo=Join-Path $Boxstarter.BaseDir BuildPackages
        MKDIR $Boxstarter.LocalRepo | Out-Null
        $key = [GUID]::NewGuid()
        [Uri]$feed="http://myfeed2"
        Set-BoxstarterFeedAPIKey -NugetFeed $feed -APIKey $key
        $Boxstarter.LocalRepo=Join-Path $Boxstarter.BaseDir LocalRepo

        $result = Get-BoxstarterFeedAPIKey -NugetFeed $feed

        it "should return the key the default repo" {
            $key | should be $result
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
