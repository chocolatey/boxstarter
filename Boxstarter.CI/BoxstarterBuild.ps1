param(
    $DeploymentTargetUserName,
    $DeploymentTargetPassword, 
    $AzureSubscriptionName,
    $AzureSubscriptionId,
    $AzureSubscriptionCertificate
)

. .\Bootstrap.ps1

Set-BoxstarterDeployOptions -DeploymentTargetUserName $DeploymentTargetUserName -DeploymentTargetPassword $DeploymentTargetPassword
Set-BoxstarterAzureOptions $AzureSubscriptionName $AzureSubscriptionId $AzureSubscriptionCertificate

Test-BoxstarterPackage