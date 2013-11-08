function Start-UpdateServices {
    write-boxstartermessage "Enabling Automatic Updates from Windows Update"
    Remove-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -name 'NoAutoUpdate' -force
    Remove-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -name 'NoAutoRebootWithLoggedOnUsers' -force    
    Start-CCMEXEC
}

function Start-CCMEXEC {
    $ccm = get-service -include CCMEXEC
    if($ccm -and $ccm.Status -ne "Running") {
        Write-BoxstarterMessage "Starting Configuration Manager Service"
        set-service CCMEXEC -startuptype automatic
        Enter-BoxstarterLogable { Start-Service CCMEXEC -ErrorAction SilentlyContinue }
    }
}