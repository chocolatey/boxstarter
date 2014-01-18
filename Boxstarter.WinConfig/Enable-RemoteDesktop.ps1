function Enable-RemoteDesktop {
<#
.SYNOPSIS
Allows Remote Desktop access to machine and enables Remote Desktop firewall rule

.LINK
http://boxstarter.codeplex.com

#>
    $obj = Get-WmiObject -Class "Win32_TerminalServiceSetting" -Namespace root\cimv2\terminalservices
    if($obj -eq $null) {
        Write-Host "Unable to locate terminalservices namespace. Remote Desktop is not enabled"
        return
    }
    $obj.SetAllowTsConnections(1,1) | out-null
}
