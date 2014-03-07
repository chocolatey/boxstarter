function Get-BoxstarterDeployOptions {
    $path = Get-OptionsPath
    $secretPath = Get-SecretOptionsPath
    if(!(Test-Path $path)) { 
        $options = @{
            DeploymentTargetNames=$null
            DeploymentTargetCredentials=$null
            DeploymentVMProvider=$null
            DeploymentCloudServiceName=$null
            RestoreCheckpoint=$null
            DefaultNugetFeed=[Uri]"http://chocolatey.org/api/v2"
            DefaultFeedAPIKey=$null
        }
    }
    else {
        $options = Import-CliXML $path
    }

    if(Test-Path $secretPath) { 
        $options.DeploymentTargetCredentials = Import-CliXML $secretPath
    }

    $options.DefaultFeedAPIKey = Get-BoxstarterFeedAPIKey -NugetFeed $options.DefaultNugetFeed

    return $options
}
