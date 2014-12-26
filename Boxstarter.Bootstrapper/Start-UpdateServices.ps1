function Start-UpdateServices {
    write-boxstartermessage "Enabling Automatic Updates from Windows Update"
    $winUpdateKey = "HKLM:SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\au"
    try { Remove-ItemProperty -Path $winUpdateKey -name 'NoAutoUpdate' -force -ErrorAction Stop } catch {$global:error.RemoveAt(0)}
    try {Remove-ItemProperty -Path $winUpdateKey -name 'NoAutoRebootWithLoggedOnUsers' -force -ErrorAction Stop} catch{$global:error.RemoveAt(0)}
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