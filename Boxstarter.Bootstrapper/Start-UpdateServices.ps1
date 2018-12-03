function Start-UpdateServices {
    Write-BoxstarterMessage "Restore Automatic Updates from Windows Update"
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
    $ccm = Get-Service -include CCMEXEC
    if($ccm -and $ccm.Status -ne "Running") {
        Write-BoxstarterMessage "Starting Configuration Manager Service"
        Set-Service CCMEXEC -startuptype automatic
        Enter-BoxstarterLogable { Start-Service CCMEXEC -ErrorAction SilentlyContinue }
    }
}
