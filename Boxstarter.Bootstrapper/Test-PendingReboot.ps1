function Test-PendingReboot {
<#
.SYNOPSIS
Checks to see if Windows is pending a reboot

.DESCRIPTION
Uses a script from Brian Wilhite
https://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542
that queries the registry, Windows Update and System
Configuration Manager to determine if a pending reboot is
required.

One may want to check this before installing software
or doing anything that may fail if there is a pending
reboot. If this command returns $true, one may want to
call Invoke-Reboot to restart the local machine.

.LINK
https://boxstarter.org
https://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542
Invoke-Reboot
about_boxstarter_bootstrapper

#>
    Write-BoxstarterMessage "Checking for Pending reboot" -Verbose
    return Remove-BoxstarterError {
        $rebootPending = Get-PendingReboot -ErrorLog $BoxStarter.Log
		if ($rebootPending.RebootPending) {
			Write-BoxstarterMessage "Detected Pending reboot" -Verbose
			Log-BoxstarterMessage "$rebootPending"
			return $true
		}
		else {
			return $false
		}
    }
}
