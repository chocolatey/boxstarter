function Set-BoxstarterDeployOptions {
<#
.SYNOPSIS
Configures settings related to boxstarter package deployment to test
machines and NuGet packages.

.DESCRIPTION
Boxstarter tests Chocolatey packages by deploying and installing the
package to a remote machine. The deployment options include settings
that control what computers to use to test the packages, the credentials
to use, VM checkpoints to snap as well as nuget feed and API key for
publishing succesful packages. To read the curent settings for these
options, use Get-BoxstarterDeploymentOptions.

.PARAMETER DeploymentTargetCredentials
The credentials to use for deploying packages to the Deployment Targets

.PARAMETER DeploymentTargetNames
Names of test targets where packages will be tested. These can be either
computer names or VM names if using one of the VM providers. The default
is localhost. When testing locally, Reboots are disabled.

.PARAMETER DeploymentVMProvider
The name of the VM provider if the deployment targts are managed using
one of the Boxstarter VM Providers: HyperV or Azure.

.PARAMETER DeploymentCloudServiceName
If using the Azure VM Provider, this is the cloud service that hosts the VM.

.PARAMETER RestoreCheckpoint
If using one of the VM Provider, this specifies a checkpoint name from which
point the package install should begin. If the checkpoint does not exist,
it will be saved just before the install.

.PARAMETER DeploymentTargetPassword
Password to use when authenticating remote sessions on the deployment
targets. Using the DeploymentTargetCredentials is preferred but explicitly
providing a username and password may be necesary for some build server
scenarios.

.PARAMETER DeploymentTargetUserName
UserName to use when authenticating remote sessions on the deployment
targets. Using the DeploymentTargetCredentials is preferred but explicitly
providing a username and password may be necesary for some build server
scenarios.

.PARAMETER DefaultNugetFeed
If an individual package has not been assigned to a specific Nugetr feed,
Boxstarter will fall back to this feed unless the package was explicitly
set to $null.

.PARAMETER DefaultFeedAPIKey
The API key to use when when publishing a package to the default feed.

.NOTES
Set-BoxstarterDeployOptions can set one or all possible settings. These
settings are persisted to a file and all credential and API key is
encrypted. Using the DeploymentTargetCredentials is preferred over explicitly
providing a username and password. But the later may be necesary for a
very limited set of build server scenarios.

.EXAMPLE
$cred=Get-Credential Admin
Set-BoxstarterDeployOptions -DeploymentTargetCredentials $cred `
  -DeploymentTargetNames "testVM1","testVM2" `
  -DeploymentVMProvider Azure -DeploymentCloudServiceName ServiceName `
  -RestoreCheckpoint clean `
  -DefaultNugetFeed https://www.myget.org/F/mywackyfeed/api/v2 `
  -DefaultFeedAPIKey 5cbc38d9-1a94-430d-8361-685a9080a6b8

This configures package deployments for Azure VMs testVM1 and testVM2
hosted in the ServiceName service using the Admin credential. Prior to
testing a package install, the VM will be restored to the clean
checkpoint. If packages are published and are not associated with a
NuGet feed, they will publish to the mywackyfeed on myget.org using API
Key 5cbc38d9-1a94-430d-8361-685a9080a6b8

.LINK
https://boxstarter.org
Get-BoxstarterDeployOptions
#>
    [CmdletBinding(DefaultParameterSetName='Credential')]
    param(
        [Parameter(ParameterSetName="Credential")]
        [Management.Automation.PsCredential]$DeploymentTargetCredentials,
        [Parameter(ParameterSetName="UserPass")]
        [string]$DeploymentTargetPassword,
        [Parameter(ParameterSetName="UserPass")]
        [string]$DeploymentTargetUserName,
        [string[]]$DeploymentTargetNames,
        [string]$DeploymentVMProvider,
        [string]$DeploymentCloudServiceName,
        [string]$RestoreCheckpoint,
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
