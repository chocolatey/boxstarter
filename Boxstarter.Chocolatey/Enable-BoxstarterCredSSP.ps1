function Enable-BoxstarterCredSSP {
<#
.SYNOPSIS
Enables and configures CredSSP Authentication to be used in PowerShell remoting sessions

.DESCRIPTION
Enabling CredSSP allows a caller from one remote session to authenticate on other remote
resources. This is known as credential delegation. By default, PowerShell sessions do not
use credSSP and therefore cannot bake a "second hop" to use other remote resources that
require their authentication token.

Enable-BoxstarterCredSSP allows remote boxstarter installs to use credential delegation
in the case where one might keep some resources on another remote machine that need to be
installed into their current remote session.

This command will enable CredSSP and add all RemoteHostsToTrust to the CredSSP trusted
hosts list. It will also edit the users group policy to allow Fresh Credential Delegation.

.PARAMETER RemoteHostsToTrust
A list of ComputerNames to add to the CredSSP Trusted hosts list.

.OUTPUTS
A list of the original trusted hosts on the local machine.

.EXAMPLE
Enable-BoxstarterCredSSP box1,box2

.LINK
https://boxstarter.org
Install-BoxstarterPackage

#>
    param(
    [string[]] $RemoteHostsToTrust
    )
    $Result=@{
        Success=$False;
        PreviousCSSPTrustedHosts=$null;
        PreviousFreshCredDelegationHostCount=0
    }
    if(!(Test-Admin)) {
        return $result
    }
    Write-BoxstarterMessage "Configuring CredSSP settings..."
    $credssp = Get-WSManCredSSP

    $ComputersToAdd = @()
    $idxHosts=$credssp[0].IndexOf(": ")
    if($idxHosts -gt -1){
        $credsspEnabled=$True
        $Result.PreviousCSSPTrustedHosts=$credssp[0].substring($idxHosts+2)
        $hostArray=$Result.PreviousCSSPTrustedHosts.Split(",")
        $RemoteHostsToTrust | ? { $hostArray -notcontains "wsman/$_" } | % { $ComputersToAdd += $_ }
    }
    else {
        $ComputersToAdd = $RemoteHostsToTrust
    }

    if($ComputersToAdd.Count -gt 0){
        Write-BoxstarterMessage "Adding $($ComputersToAdd -join ',') to allowed credSSP hosts" -Verbose
        try {
            Enable-WSManCredSSP -DelegateComputer $ComputersToAdd -Role Client -Force -ErrorAction Stop | Out-Null
        }
        catch {
            Write-BoxstarterMessage "Enable-WSManCredSSP failed with: $_" -Verbose
            return $result
        }
    }

    $key = Get-CredentialDelegationKey
    if (!(Test-Path "$key\CredentialsDelegation")) {
        New-Item $key -Name CredentialsDelegation | Out-Null
    }
    $key = Join-Path $key "CredentialsDelegation"
    New-ItemProperty -Path "$key" -Name "ConcatenateDefaults_AllowFresh" -Value 1 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path "$key" -Name "ConcatenateDefaults_AllowFreshNTLMOnly" -Value 1 -PropertyType Dword -Force | Out-Null

    $result.PreviousFreshNTLMCredDelegationHostCount = Set-CredentialDelegation $key 'AllowFreshCredentialsWhenNTLMOnly' $RemoteHostsToTrust
    $result.PreviousFreshCredDelegationHostCount = Set-CredentialDelegation $key 'AllowFreshCredentials' $RemoteHostsToTrust

    $Result.Success=$True
    return $Result
}

function Set-CredentialDelegation($key, $subKey, $allowed){
    New-ItemProperty -Path "$key" -Name $subKey -Value 1 -PropertyType Dword -Force | Out-Null
    $policyNode = Join-Path $key $subKey
    if (!(Test-Path $policyNode)) {
        md $policyNode | Out-Null
    }
    $currentHostProps=@()
    (Get-Item $policyNode).Property | % {
        $currentHostProps += (Get-ItemProperty -Path $policyNode -Name $_).($_)
    }
    $currentLength = $currentHostProps.Length
    $idx=$currentLength
    $allowed | ? { $currentHostProps -notcontains "wsman/$_"} | % {
        ++$idx
        New-ItemProperty -Path $policyNode -Name "$idx" -Value "wsman/$_" -PropertyType String -Force | Out-Null
    }

    return $currentLength
}

function Get-CredentialDelegationKey {
    return "HKLM:\SOFTWARE\Policies\Microsoft\Windows"
}
