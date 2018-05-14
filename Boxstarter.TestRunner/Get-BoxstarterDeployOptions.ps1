function Get-BoxstarterDeployOptions {
<#
.SYNOPSIS
Lists all Boxstarter deployment options currently set

.DESCRIPTION
Boxstarter tests Chocolatey packages by deploying and installing the
package to a remote machine. The deployment options include settings
that control what computers to use to test the packages, the credentials
to use, VM checkpoints to snap as well as NuGet feed and API key for
publishing successful packages. To change these options, use
Set-BoxstarterDeploymentOptions.

.LINK
https://boxstarter.org
Set-BoxstarterDeployOptions
#>
    $path = Get-OptionsPath
    $secretPath = Get-SecretOptionsPath
    $fallbackSecretPath = "$($Boxstarter.BaseDir)\BuildPackages\BoxstarterScripts\$env:ComputerName-$env:username-Options.xml"
    if(!(Test-Path $path)) {
        $options = @{
            DeploymentTargetNames="localhost"
            DeploymentTargetCredentials=$null
            DeploymentVMProvider=$null
            DeploymentCloudServiceName=$null
            RestoreCheckpoint=$null
            DefaultNugetFeed=[Uri]"https://chocolatey.org/api/v2"
            DefaultFeedAPIKey=$null
        }
    }
    else {
        $options = Import-CliXML $path
    }

    if(Test-Path $secretPath) {
        $options.DeploymentTargetCredentials = Import-CliXML $secretPath
    }
    elseif(Test-Path $fallbackSecretPath) {
        Write-BoxstarterMessage "Falling back to default local repo for secrets" -Verbose
        $options.DeploymentTargetCredentials = Import-CliXML $fallbackSecretPath
    }

    $options.DefaultFeedAPIKey = Get-BoxstarterFeedAPIKey -NugetFeed $options.DefaultNugetFeed

    return $options
}
