function Enable-BoxstarterClientRemoting ($RemoteHostToTrust) {
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
            Enable-PSRemoting -Force
        }else {
            Write-BoxstarterMessage "Not enabling local Powershell Remoting aborting package install"
            return $Result
        }
    }

    if($credssp -is [Object[]]){
        $idxHosts=$credssp[0].IndexOf(": ")
        if($idxHosts -gt -1){
            $credsspEnabled=$True
            $Result.PreviousCSSPTrustedHosts=$credssp[0].substring($idxHosts+2)
            $hostArray=$Result.PreviousCSSPTrustedHosts.Split(",")
            if($hostArray -contains "wsman/$RemoteHostToTrust"){
                $ComputerAdded=$True
            }
        }
    }

    if($ComputerAdded -eq $null){
        Write-BoxstarterMessage "Adding $RemoteHostToTrust to allowed credSSP hosts"
        Enable-WSManCredSSP -DelegateComputer $RemoteHostToTrust -Role Client -Force
    }

    $Result.PreviousTrustedHosts=(Get-Item "wsman:\localhost\client\trustedhosts").Value
    $hostArray=$Result.PreviousTrustedHosts.Split(",")
    if($hostArray.length -eq 1 -and $hostArray[0].length -eq 0) {
        $newHosts=$RemoteHostToTrust
    }
    elseif(!($hostArray -contains $RemoteHostToTrust)){
        $newHosts=$Result.PreviousTrustedHosts + "," + $RemoteHostToTrust
    }
    if($newHosts -ne $null) {
        Write-BoxstarterMessage "Adding $newHosts to allowed wsman hosts"
        Set-Item "wsman:\localhost\client\trustedhosts" -Value $newHosts -Force
    }

    $result.PreviousFreshCredDelegationHostCount = [int](Add-CredSSPGroupPolicy $RemoteHostToTrust)
    $Result.Success=$True
    return $Result
}

function Add-CredSSPGroupPolicy([string]$allowed){
    $allowed='wsman/' + $allowed
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
    if(!($currentHostProps -contains $allowed)){
        New-ItemProperty -Path $key -Name $($currentHostProps.Length+1) -Value $allowed -PropertyType String -Force | Out-Null
    }

    return $currentLength
}

function Get-CredentialDelegationKey {
    return "HKLM:\SOFTWARE\Policies\Microsoft\Windows"
}