function Set-BoxstarterDeployOptions {
    [CmdletBinding()]
    param(
        [Management.Automation.PsCredential]$DeploymentTargetCredentials,
        [string[]]$DeploymentTargetNames,
        [string]$DeploymentVMProvider,
        [string]$DeploymentCloudServiceName,
        [string]$RestoreCheckpoint,
        [string]$DeploymentTargetPassword,
        [string]$DeploymentTargetUserName,
        [Uri]$DefaultNugetFeed,
        [GUID]$DefaultFeedAPIKey
    )
    $options=Get-BoxstarterDeployOptions
    if($PSBoundParameters.Keys -contains "DeploymentTargetCredentials"){$options.DeploymentTargetCredentials = $DeploymentTargetCredentials}
    if($PSBoundParameters.Keys -contains "DeploymentTargetNames"){$options.DeploymentTargetNames = $DeploymentTargetNames}
    if($PSBoundParameters.Keys -contains "DeploymentVMProvider"){$options.DeploymentVMProvider = $DeploymentVMProvider}
    if($PSBoundParameters.Keys -contains "DeploymentCloudServiceName"){$options.DeploymentCloudServiceName = $DeploymentCloudServiceName}
    if($PSBoundParameters.Keys -contains "RestoreCheckpoint"){$options.RestoreCheckpoint = $RestoreCheckpoint}
    if($PSBoundParameters.Keys -contains "DefaultNugetFeed"){$options.DefaultNugetFeed = $DefaultNugetFeed}
    
    if($PSBoundParameters.Keys -contains "DeploymentTargetUserName"){
        $secpasswd = ConvertTo-SecureString $DeploymentTargetPassword -AsPlainText -Force
        $options.DeploymentTargetCredentials = New-Object System.Management.Automation.PSCredential ($DeploymentTargetUserName, $secpasswd)
    }
    $options.DeploymentTargetCredentials | Export-CliXML (Get-SecretOptionsPath)
    $options.Remove("DeploymentTargetCredentials")

    if($PSBoundParameters.Keys -contains "DefaultFeedAPIKey"){
        Set-BoxstarterFeedAPIKey -NugetFeed $options.DefaultNugetFeed -APIKey $DefaultFeedAPIKey
    }
    $options.Remove("DefaultFeedAPIKey")

    $options | Export-CliXML (Get-OptionsPath)
}
