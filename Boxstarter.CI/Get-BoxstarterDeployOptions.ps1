function Get-BoxstarterDeployOptions {
    $path = Get-OptionsPath
    $secretPath = Get-SecretOptionsPath
    if(!(Test-Path $path)) { 
        $options = @{
            DeploymentTargetNames=$null
            DeploymentVMProvider=$null
            DeploymentCloudServiceName=$null
            RestoreCheckpoint=$null
            DefaultNugetFeed=[Uri]"http://chocolatey.org/api/v2"
        }
    }
    else {
        $options = Import-CliXML $path
    }

    if(!(Test-Path $secretPath)) { 
        $options.DeploymentTargetCredentials=$null
    }
    else {
        $options.DeploymentTargetCredentials = Import-CliXML $secretPath
    }

    return $options
}
