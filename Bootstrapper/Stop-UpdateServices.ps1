function Stop-UpdateServices {
    Stop-Service -Name wuauserv
    Stop-CCMEXEC
}

function Stop-CCMEXEC {
    $ccm = (get-service -include CCMEXEC)
    if($ccm) {
        set-service CCMEXEC -startuptype disabled
        do {
            if($ccm.CanStop) { 
                Write-Output "Stopping Configuration Manager"
                Stop-Service CCMEXEC
                return
            }
            Write-Output "Waiting for Computer Configuration Manager to stop..."
            sleep 10
        } while (-not ($ccm.CanStop) -and ($i++ -lt 5))
    }
}