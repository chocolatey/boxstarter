function Enable-RemoteDesktop {
<#
.SYNOPSIS
Allows Remote Desktop access to machine and enables Remote Desktop firewall rule

.PARAMETER NLA
Changes the if Remote Desktop requires Network Level Authentication.  Valid inputs are On and Off.

.LINK
http://boxstarter.org

#>

    param(
        [Parameter(Position=0)]
        [ValidateSet("On", "Off", ignorecase=$True)]
        [String]
	$NLA="On"
	)
    
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

    $obj2 = Get-WmiObject -class Win32_TSGeneralSetting -Namespace root\cimv2\terminalservices -ComputerName . -Filter "TerminalName='RDP-tcp'"
    
    if($obj2.UserAuthenticationRequired -eq $null) {
        Write-BoxstarterMessage "Unable to locate Remote Desktop NLA namespace. Remote Desktop NLA is not enabled"
        return
    }
    try {
        switch ($NLA) {
			"On" { $obj2.SetUserAuthenticationRequired(1) | out-null
            Write-BoxstarterMessage "Enabling Remote Desktop NLA ..."    
            }
			"Off" { $obj2.SetUserAuthenticationRequired(0) | out-null
            Write-BoxstarterMessage "Disabling Remote Desktop NLA ..."
            }
		}
    }
    catch {
        throw "There was a problem enabling Remote Desktop NLA. Make sure your operating system supports Remote Desktop NLA and there is no group policy preventing you from enabling it."
    }	
}
