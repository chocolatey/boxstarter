param(
    $DeploymentTargetUserName,
    $DeploymentTargetPassword,
    $FeedAPIKey,
    $AzureSubscriptionName,
    $AzureSubscriptionId,
    $AzureSubscriptionCertificate
)

#Download everything we need and import modules
. .\Bootstrap.ps1

#Configure our settings
$Boxstarter.LocalRepo=(Resolve-Path "$PSScriptRoot\..\")
Set-BoxstarterDeployOptions -DeploymentTargetUserName $DeploymentTargetUserName -DeploymentTargetPassword $DeploymentTargetPassword
if(![string]::IsNullOrEmpty($FeedAPIKey)) {
    Set-BoxstarterDeployOptions -DefaultFeedAPIKey $FeedAPIKey
}
Set-BoxstarterAzureOptions $AzureSubscriptionName $AzureSubscriptionId $AzureSubscriptionCertificate

#We want to exit with an unsuccesful exit code if any tests fail or not tests are run at all
$failedTests=0
$totalTests=0
Test-BoxstarterPackage -IncludeOutput | % {
    if($_.Package){
        $totalTests++
    }
    if($_.Status -eq "failed"){
        $failedTests++
    }
    $_
}

if ($totalTests -eq 0) {
    throw "no tests performed. That cant be right."
}
Exit $failedTests