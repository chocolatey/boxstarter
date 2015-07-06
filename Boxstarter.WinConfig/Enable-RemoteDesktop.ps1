function Enable-RemoteDesktop {
<#
.SYNOPSIS
Allows Remote Desktop access to machine and enables Remote Desktop firewall rule

.LINK
http://boxstarter.org

#>
    Write-BoxstarterMessage "Enabling Remote Desktop..."
    $obj = Get-WmiObject -Class "Win32_TerminalServiceSetting" -Namespace root\cimv2\terminalservices
    if($obj -eq $null) {
        Write-BoxstarterMessage "Unable to locate terminalservices namespace. Remote Desktop is not enabled"
        return
    }
    try {
        $obj.SetAllowTsConnections(1,1) | out-null
    }
    catch {
        throw "There was a problem enabling remote desktop. Make sure your operating system supports remote desktop and there is no group policy preventing you from enabling it."
    }
}
