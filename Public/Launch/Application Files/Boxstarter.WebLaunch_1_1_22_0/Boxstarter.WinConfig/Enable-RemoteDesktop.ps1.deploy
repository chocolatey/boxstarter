function Enable-RemoteDesktop {
<#
.SYNOPSIS
Allows Remote Desktop access to machine and enables Remote Desktop firewall rule

.LINK
http://boxstarter.codeplex.com

#>
    (Get-WmiObject -Class "Win32_TerminalServiceSetting" -Namespace root\cimv2\terminalservices).SetAllowTsConnections(1) | out-null
    netsh advfirewall firewall set rule group="Remote Desktop" new enable=yes | out-null
}
