function Stop-UpdateServices {
    write-boxstartermessage "Stopping Windows Update Services"
    Enter-BoxstarterLogable { 
        while((get-Service -Name wuauserv).Status -ne "Stopped"){
            Stop-Service -Name wuauserv -force 
            Start-Sleep -Seconds 1
        }
        Set-Service -Name wuauserv -StartupType Disabled
    }
    Stop-CCMEXEC
}

function Stop-CCMEXEC {
    $ccm = (get-service -include CCMEXEC)
    if($ccm) {
        set-service CCMEXEC -startuptype disabled
        do {
            if($ccm.CanStop) { 
                Write-boxstartermessage "Stopping Configuration Manager"
                Enter-BoxstarterLogable { Stop-Service CCMEXEC }
                return
            }
            Write-boxstartermessage "Waiting for Computer Configuration Manager to stop..."
            sleep 10
        } while (-not ($ccm.CanStop) -and ($i++ -lt 5))
    }
}