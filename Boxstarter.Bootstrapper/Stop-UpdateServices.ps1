function Stop-UpdateServices {
    Write-BoxstarterMessage "Disabling Automatic Updates from Windows Update"
    $winUpdateKey = "HKLM:SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\au"
    if(!(Test-Path $winUpdateKey) ) { New-Item $winUpdateKey -Type Folder -Force | Out-Null }

    Remove-BoxstarterError {
        # Backup original value
        Rename-ItemProperty -Path $winUpdateKey -Name 'NoAutoUpdate' -NewName 'NoAutoUpdate_BAK'

        New-ItemProperty -Path $winUpdateKey -name 'NoAutoUpdate' -value '1' -propertyType "DWord" -force | Out-Null
        New-ItemProperty -Path $winUpdateKey -name 'NoAutoRebootWithLoggedOnUsers' -value '1' -propertyType "DWord" -force | Out-Null
    }
    Stop-CCMEXEC
}

function Stop-CCMEXEC {
    $ccm = (Get-Service -include CCMEXEC)
    if($ccm) {
        Set-Service CCMEXEC -startuptype disabled
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
