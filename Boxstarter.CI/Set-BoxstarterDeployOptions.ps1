function Set-BoxstarterDeployOptions {
    param(
        [Management.Automation.PsCredential]$DeploymentTargetCredentials,
        [string[]]$DeploymentTargetNames,
        [string]$DeploymentVMProvider,
        [string]$DeploymentCloudServiceName,
        [string]$RestoreCheckpoint,
        [string]$DeploymentTargetPassword,
        [string]$DeploymentTargetUserName
    )
    $options=Get-BoxstarterDeployOptions
    if($DeploymentTargetCredentials){$options.DeploymentTargetCredentials = $DeploymentTargetCredentials}
    if($DeploymentTargetNames){$options.DeploymentTargetNames = $DeploymentTargetNames}
    if($DeploymentVMProvider){$options.DeploymentVMProvider = $DeploymentVMProvider}
    if($DeploymentCloudServiceName){$options.DeploymentCloudServiceName = $DeploymentCloudServiceName}
    if($RestoreCheckpoint){$options.RestoreCheckpoint = $RestoreCheckpoint}
    if($DeploymentTargetUserName){
        $secpasswd = ConvertTo-SecureString $DeploymentTargetPassword -AsPlainText -Force
        $options.DeploymentTargetCredentials = New-Object System.Management.Automation.PSCredential ($DeploymentTargetUserName, $secpasswd)
    }
    $options.DeploymentTargetCredentials | Export-CliXML (Get-SecretOptionsPath)
    $options.Remove("DeploymentTargetCredentials")
    $options | Export-CliXML (Get-OptionsPath)
}
