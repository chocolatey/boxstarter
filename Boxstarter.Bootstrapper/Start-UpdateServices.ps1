function Start-UpdateServices {
    write-boxstartermessage "Restore Automatic Updates from Windows Update"
    $winUpdateKey = "HKLM:SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\au"

    Remove-BoxstarterError {
        Remove-ItemProperty -Path $winUpdateKey -name 'NoAutoUpdate' -force
        Remove-ItemProperty -Path $winUpdateKey -name 'NoAutoRebootWithLoggedOnUsers' -force

        # Restore original value
        Rename-ItemProperty -Path $winUpdateKey -NewName 'NoAutoUpdate' -Name 'NoAutoUpdate_BAK'
    }

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