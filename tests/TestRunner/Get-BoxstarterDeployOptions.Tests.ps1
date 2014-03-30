$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.TestRunner){Remove-Module Boxstarter.TestRunner}
Resolve-Path $here\..\..\Boxstarter.Common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Chocolatey\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.TestRunner\*.ps1 | 
    ? { $_.Path -like "*-*" } | 
    % { . $_.ProviderPath }

Describe "Get-BoxstarterDeployOptions" {
    $Boxstarter.BaseDir=(Get-PSDrive TestDrive).Root
    $Boxstarter.LocalRepo=Join-Path $Boxstarter.BaseDir LocalRepo
    MKDIR $Boxstarter.LocalRepo | Out-Null
    $Boxstarter.SuppressLogging=$true

    Context "When Getting options that have not been set" {
        $result = Get-BoxstarterDeployOptions

        it "should return the chocolatey feed as the default nuget feed" {
            $result.DefaultNugetFeed | should be "http://chocolatey.org/api/v2"
        }
    }

   Context "When secrets are in the default localrepo and not the localrepo" {
        $Boxstarter.LocalRepo=Join-Path $Boxstarter.BaseDir BuildPackages
        MKDIR $Boxstarter.LocalRepo | Out-Null
        Set-BoxstarterDeployOptions -DeploymentTargetPassword passwd `
                                    -DeploymentTargetUserName Admin
        $Boxstarter.LocalRepo=Join-Path $Boxstarter.BaseDir LocalRepo
    
        $result = Get-BoxstarterDeployOptions

        it "should return the credential in the default repo" {
            $result.DeploymentTargetCredentials.UserName | should be "Admin"
            $result.DeploymentTargetCredentials.GetNetworkCredential().Password | should be "passwd"
        }
    }

    Context "When Getting existing options" {
        $key=[guid]::NewGuid()
        Set-BoxstarterDeployOptions -DeploymentTargetNames @("targetvm1","targetvm2") `
                                    -DeploymentVMProvider azure `
                                    -DeploymentCloudServiceName myservice `
                                    -DeploymentTargetPassword passwd `
                                    -DeploymentTargetUserName Admin `
                                    -DefaultNugetFeed "http://www.myget.org/F/boxstarter/api/v2" `
                                    -DefaultFeedAPIKey $key
        $result = Get-BoxstarterDeployOptions

        it "should get target" {
            $result.DeploymentTargetNames[0] | should be "targetvm1"
            $result.DeploymentTargetNames[1] | should be "targetvm2"
            $result.DeploymentTargetNames.Count | should be 2
        }
        it "should get vm provider" {
            $result.DeploymentVMProvider | should be "azure"
        }
        it "should get cloud service" {
            $result.DeploymentCloudServiceName | should be "myservice"
        }
        it "should get credentials" {
            $result.DeploymentTargetCredentials.UserName | should be "Admin"
            $result.DeploymentTargetCredentials.GetNetworkCredential().Password | should be "passwd"
        }
        it "should put options file in the right place" {
            "$($Boxstarter.LocalRepo)\BoxstarterScripts\options.xml" | should exist
        }
        it "should put secrets options file in the right place" {
            "$($Boxstarter.LocalRepo)\BoxstarterScripts\$env:computername-$env:USERNAME-options.xml" | should exist
        }
        it "should get default nuget feed" {
            $result.DefaultNugetFeed | should be "http://www.myget.org/F/boxstarter/api/v2"
        }
        it "should get default nuget feed API key" {
            $result.DefaultFeedAPIKey | should be $key 
        }
    }
}