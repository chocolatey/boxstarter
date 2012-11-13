function Enable-RemoteDesktop {
    (Get-WmiObject -Class "Win32_TerminalServiceSetting" -Namespace root\cimv2\terminalservices).SetAllowTsConnections(1)
    netsh advfirewall firewall set rule group="Remote Desktop" new enable=yes
}
