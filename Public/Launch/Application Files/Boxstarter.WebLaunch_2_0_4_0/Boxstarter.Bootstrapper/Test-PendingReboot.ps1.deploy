function Test-PendingReboot {
<#
.SYNOPSIS
Checks to see if Windows is pending a reboot

.DESCRIPTION
Uses a script from Brian Wilhite 
http://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542 
that queries the registry, Windows Update and System C
onfiguration Manager to determine if a pending reboot is 
required.

One may want to check this before installing software 
or doing anything that may fail if there is a pending 
reboot. If this command returns $true, one may want to
call Invoke-Reboot to restart the local machine.

.LINK
http://boxstarter.codeplex.com
http://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542 
Invoke-Reboot
about_boxstarter_bootstrapper

#>
    $rebootPending = Get-PendingReboot -ErrorLog $BoxStarter.Log
    if($rebootPending.RebootPending) {
        Write-BoxstarterMessage "Detected Pending reboot"
        Log-BoxstarterMessage "$rebootPending"
        return $true
    }
    return IsCCMRebootPending
}

function IsCCMRebootPending {
    try { $clientutils = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities" } catch{}
    if($clientutils) {
        try {
            $determination=$clientutils.DetermineIfRebootPending()
            $isPending=$determination.RebootPending
            if($isPending){Write-BoxstarterMessage "Configuration manager is pending reboot"}
            return $isPending
            } catch {}
    }
    return $false
}