function Start-UpdateServices {
    write-boxstartermessage "Enabling Automatic Updates from Windows Update"
    try { Remove-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -name 'NoAutoUpdate' -force -ErrorAction Stop } catch {$global:error.RemoveAt(0)}
    try {Remove-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -name 'NoAutoRebootWithLoggedOnUsers' -force -ErrorAction Stop} catch{$global:error.RemoveAt(0)}
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