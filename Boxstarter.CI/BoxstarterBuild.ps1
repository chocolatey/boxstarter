param(
    $PublishSuccesfulPackages,
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

Publish-BoxstarterPassedTestResults
#We want to exit with an unsuccessful exit code if any tests fail or not tests are run at all
$failedTests=0
$testedPackage = @()
Test-BoxstarterPackage -IncludeOutput | % {
    if($_.Package){
        $testedPackage += $_
        if($_.Status -eq "failed"){
            $failedTests++
        }
    }
    $_
}

if($PublishSuccesfulPackages){
    $testedPackage | Select-BoxstarterResultsToPublish | Publish-BoxstarterPackage
}

if ($testedPackage.Count -eq 0) {
    throw "no tests performed. That cant be right."
}
Exit $failedTests