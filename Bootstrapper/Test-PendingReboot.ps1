function Test-PendingReboot {
    $rebootPending = Get-PendingReeboot -ErrorLog $BoxStarter.ErrorLog
    if($rebootPending.RebootPending) {return $true;}
    return IsCCMRebootPending
}

function IsCCMRebootPending {
    try { $clientutils = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities" } catch{}
    if($clientutils) {
        try {
            $determination=$clientutils.DetermineIfRebootPending()
            $isPending=$determination.RebootPending
            return $isPending
            } catch {}
    }
    return $false
}