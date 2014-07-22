function Stop-UpdateServices {
    write-boxstartermessage "Disabling Automatic Updates from Windows Update"
    try {New-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -name 'NoAutoUpdate' -value '1' -propertyType "DWord" -force -ErrorAction Stop | Out-Null}catch { $global:error.RemoveAt(0) }
    try {New-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -name 'NoAutoRebootWithLoggedOnUsers' -value '1' -propertyType "DWord" -force -ErrorAction Stop | Out-Null}catch { $global:error.RemoveAt(0) }
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