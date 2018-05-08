function Enable-BoxstarterClientRemoting {
<#
.SYNOPSIS
Enables and configures PowerShell remoting from the client

.DESCRIPTION
Enable-BoxstarterClientRemoting will check if PowerShell Remoting is enabled on the local
machine. If not, it will enable it and it will also add all remote hosts to trust to the
WSMAN trusted hosts list. The original trusted host list will be returned. When running
Install-BoxstarterPackage, Boxstarter will roll back to the original trusted hosts when
the package install is complete.

.PARAMETER RemoteHostsToTrust
A list of ComputerNames to add to the WSMAN Trusted hosts list.

.OUTPUTS
A list of the original trusted hosts on the local machine as well as a bool indicating
if PowerShell Remoting was successfully completed.

.EXAMPLE
Enable-BoxstarterClientRemoting box1,box2

.LINK
https://boxstarter.org
Install-BoxstarterPackage

#>
    param(
    [string[]] $RemoteHostsToTrust
    )
    if(Test-Admin) { $elevated = $true }

    $Result=@{
        Success=$False;
        PreviousTrustedHosts=$null;
    }
    Write-BoxstarterMessage "Configuring local PowerShell Remoting settings..."

    if(!(Get-Command Test-WSMan -ErrorAction SilentlyContinue)) {
        #I have only seen this on VisualStudio.Com Hosted build servers
        $Result.Success=$True
        return $Result
    }

    try { $wsman = Test-WSMan -ErrorAction Stop } catch { $credssp = $_}
    if($credssp.Exception -ne $null){
        Write-BoxstarterMessage "Local PowerShell Remoting is not enabled" -Verbose
        Write-BoxstarterMessage "Error returned $($credssp.ToString())" -Verbose
        if($elevated -and ($Force -or (Confirm-Choice "PowerShell remoting is not enabled locally. Should Boxstarter enable PowerShell remoting?")))
        {
            Write-BoxstarterMessage "Enabling PowerShell Remoting on local machine"
            $enableArgs=@{Force=$true}
            $command=Get-Command Enable-PSRemoting
            if($command.Parameters.Keys -contains "skipnetworkprofilecheck"){
                $enableArgs.skipnetworkprofilecheck=$true
            }
            Enable-PSRemoting @enableArgs | Out-Null
        }else {
            Write-BoxstarterMessage "Not enabling local PowerShell Remoting aborting package install"
            return $Result
        }
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

    $Result.Success=$True
    return $Result
}
