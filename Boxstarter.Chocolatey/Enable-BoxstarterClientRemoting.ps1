function Enable-BoxstarterClientRemoting ([string[]] $RemoteHostsToTrust) {
    $Result=@{    
        Success=$False;
        PreviousTrustedHosts=$null;
        PreviousCSSPTrustedHosts=$null;
        PreviousFreshCredDelegationHostCount=0
    }

    try { $credssp = Get-WSManCredSSP } catch { $credssp = $_}
    if($credssp.Exception -ne $null){
        Write-BoxstarterMessage "Local Powershell Remoting is not enabled"
        if($Force -or (Confirm-Choice "Powershell remoting is not enabled locally. Should Boxstarter enable powershell remoting?"))
        {
            Write-BoxstarterMessage "Enabling local Powershell Remoting"
            $enableArgs=@{Force=$true}
            $command=Get-Command Enable-PSRemoting
            if($command.Parameters.Keys -contains "skipnetworkprofilecheck"){
                $enableArgs.skipnetworkprofilecheck=$true
            }
            Enable-PSRemoting @enableArgs | Out-Null
        }else {
            Write-BoxstarterMessage "Not enabling local Powershell Remoting aborting package install"
            return $Result
        }
    }

    $ComputersToAdd = @()
    if($credssp -is [Object[]]){
        $idxHosts=$credssp[0].IndexOf(": ")
        if($idxHosts -gt -1){
            $credsspEnabled=$True
            $Result.PreviousCSSPTrustedHosts=$credssp[0].substring($idxHosts+2)
            $hostArray=$Result.PreviousCSSPTrustedHosts.Split(",")
            $RemoteHostsToTrust | ? { $hostArray -notcontains "wsman/$_" } | % { $ComputersToAdd += $_ }
        }
    }

    if($ComputersToAdd.Count -gt 0){
        Write-BoxstarterMessage "Adding $($ComputersToAdd -join ',') to allowed credSSP hosts"
        Enable-WSManCredSSP -DelegateComputer $ComputersToAdd -Role Client -Force | Out-Null
    }

    $newHosts = @()
    $Result.PreviousTrustedHosts=(Get-Item "wsman:\localhost\client\trustedhosts").Value
    $hostArray=$Result.PreviousTrustedHosts.Split(",")
    $RemoteHostsToTrust | ? { $hostArray -NotContains $_ } | % { $newHosts += $_ }
    if($newHosts.Count -gt 0) {
        $strNewHosts = $newHosts -join ","
        Write-BoxstarterMessage "Adding $strNewHosts to allowed wsman hosts"
        Set-Item "wsman:\localhost\client\trustedhosts" -Value ($Result.PreviousTrustedHosts + "," + $strNewHosts) -Force
    }

    $result.PreviousFreshCredDelegationHostCount = [int](Add-CredSSPGroupPolicy $RemoteHostsToTrust)
    $Result.Success=$True
    return $Result
}

function Add-CredSSPGroupPolicy([string[]]$allowed){
    $key = Get-CredentialDelegationKey
    if (!(Test-Path "$key\CredentialsDelegation")) {
        New-Item $key -Name CredentialsDelegation | Out-Null
    }
    New-ItemProperty -Path "$key\CredentialsDelegation" -Name AllowFreshCredentialsWhenNTLMOnly -Value 1 -PropertyType Dword -Force | Out-Null

    $key = Join-Path $key 'CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly'
    if (!(Test-Path $key)) {
        md $key | Out-Null
    }
    $currentHostProps=@()
    (Get-Item $key).Property | % {
        $currentHostProps += (Get-ItemProperty -Path $key -Name $_).($_)
    }
    $currentLength = $currentHostProps.Length
    $idx=$currentLength
    $allowed | ? { $currentHostProps -notcontains "wsman/$_"} | % {
        New-ItemProperty -Path $key -Name $($++idx) -Value "wsman/$_" -PropertyType String -Force | Out-Null
    }

    return $currentLength
}

function Get-CredentialDelegationKey {
    return "HKLM:\SOFTWARE\Policies\Microsoft\Windows"
}