function Enable-BoxstarterClientRemoting ([string[]] $RemoteHostsToTrust) {
    $Result=@{    
        Success=$False;
        PreviousTrustedHosts=$null;
        PreviousCSSPTrustedHosts=$null;
        PreviousFreshCredDelegationHostCount=0
    }
    Write-BoxstarterMessage "Configuring local Powershell Remoting settings..."
    try { $credssp = Get-WSManCredSSP } catch { $credssp = $_}
    if($credssp.Exception -ne $null){
        Write-BoxstarterMessage "Local Powershell Remoting is not enabled" -Verbose
        if($Force -or (Confirm-Choice "Powershell remoting is not enabled locally. Should Boxstarter enable powershell remoting?"))
        {
            Write-BoxstarterMessage "Enabling Powershell Remoting on local machine"
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
        else {
            $ComputersToAdd = $RemoteHostsToTrust
        }
    }

    if($ComputersToAdd.Count -gt 0){
        Write-BoxstarterMessage "Adding $($ComputersToAdd -join ',') to allowed credSSP hosts" -Verbose
        Enable-WSManCredSSP -DelegateComputer $ComputersToAdd -Role Client -Force | Out-Null
    }

    $newHosts = @()
    $Result.PreviousTrustedHosts=(Get-Item "wsman:\localhost\client\trustedhosts").Value
    $hostArray=$Result.PreviousTrustedHosts.Split(",")
    if($hostArray -contains "*") {
        $Result.PreviousTrustedHosts = $null
    }
    else {
        $RemoteHostsToTrust | ? { $hostArray -NotContains $_ } | % { $newHosts += $_ }
        if($newHosts.Count -gt 0) {
            $strNewHosts = $newHosts -join ","
            if($Result.PreviousTrustedHosts.Length -gt 0){
                $strNewHosts = $Result.PreviousTrustedHosts + "," + $strNewHosts
            }
            Write-BoxstarterMessage "Adding $strNewHosts to allowed wsman hosts" -Verbose
            Set-Item "wsman:\localhost\client\trustedhosts" -Value $strNewHosts -Force
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