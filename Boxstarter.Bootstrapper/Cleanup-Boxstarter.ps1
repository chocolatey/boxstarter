function Cleanup-Boxstarter {
    param(
        [switch]$KeepWindowOpen,
        [switch]$DisableRestart)
    if (Get-IsRemote) {
        Remove-BoxstarterTask
    }
    Start-UpdateServices

    $extensionBaseDir = "$env:ChocolateyInstall\extensions\boxstarter-choco"
    if (Test-Path $extensionBaseDir) {
        Remove-Item $extensionBaseDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$(Join-Path $env:temp 'Boxstarter.ext.*')" -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path "$(Get-BoxstarterTempDir)\BoxstarterReEnableUAC") {
        $uacLevel = Get-Content "$(Get-BoxstarterTempDir)\BoxstarterReEnableUAC"
        Remove-Item "$(Get-BoxstarterTempDir)\BoxstarterReEnableUAC"
        Enable-UAC
        if ($uacLevel) {
            Set-BoxstarterConsentPromptBehaviorAdmin -ConsentPromptBehavior $uacLevel
            Write-BoxstarterMessage "Re-enabled UAC with ConsentPromptBehaviorAdmin set to $uacLevel"
        }
    }
    if (!$Boxstarter.IsRebooting) {
        Write-BoxstarterMessage 'Cleaning up and not rebooting' -Verbose
        $startup = "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup"
        if ( Test-Path "$Startup\boxstarter-post-restart.bat") {
            Write-BoxstarterMessage 'Cleaning up restart file' -Verbose
            Remove-Item "$Startup\boxstarter-post-restart.bat"
            Remove-Item "$(Get-BoxstarterTempDir)\Boxstarter.Script"
            $promptToExit = $true
        }
        if (Test-Path "$(Get-BoxstarterTempDir)\Boxstarter.autologon") {
            Write-BoxstarterMessage 'Cleaning up autologon registry keys' -Verbose
            $winLogonKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
            $winlogonProps = Import-Clixml -Path "$(Get-BoxstarterTempDir)\Boxstarter.autologon"
            @('DefaultUserName', 'DefaultDomainName', 'DefaultPassword', 'AutoAdminLogon') | ForEach-Object {
                if (!$winlogonProps.ContainsKey($_)) {
                    Remove-ItemProperty -Path $winLogonKey -Name $_ -ErrorAction SilentlyContinue
                }
                else {
                    Set-ItemProperty -Path $winLogonKey -Name $_ -Value $winlogonProps[$_]
                }
            }
            Remove-Item -Path "$(Get-BoxstarterTempDir)\Boxstarter.autologon"
        }
        if ($promptToExit -or $KeepWindowOpen) {
            Read-Host 'Type ENTER to exit'
        }
        return
    }

    if (!(Get-IsRemote -PowershellRemoting) -and !$DisableRestart) {
        if (Get-UAC) {
            Write-BoxstarterMessage 'UAC Enabled. Disabling...'
            # only _disable_ UAC prior to Win2016
            # Windows Server 2016 is version 10.0.14393
            $minVersion = [version]'10.0.14393'
            $currentVersion = [System.Environment]::OSVersion.Version

            if ($currentVersion -lt $minVersion) {
                Write-Output 'Windows version is less than Windows Server 2016.'
                Disable-UAC
            }
            else {
                Write-Output 'Windows version is Windows Server 2016 or newer.'
            }
            $uacLevel = Get-BoxstarterConsentPromptBehaviorAdmin
            if (-Not (Test-Path "$(Get-BoxstarterTempDir)\BoxstarterReEnableUAC")) {
                Set-Content "$(Get-BoxstarterTempDir)\BoxstarterReEnableUAC" $uacLevel
            }
            Set-BoxstarterConsentPromptBehaviorAdmin -ConsentPromptBehavior 'NeverNotify'
        }
    }

    if (!(Get-IsRemote -PowershellRemoting) -and $BoxstarterPassword.Length -gt 0) {
        $currentUser = Get-CurrentUser
        Write-BoxstarterMessage "Securely Storing $($currentUser.Domain)\$($currentUser.Name) credentials for automatic logon"
        Set-SecureAutoLogon $currentUser.Name $BoxstarterPassword $currentUser.Domain -BackupFile "$(Get-BoxstarterTempDir)\Boxstarter.autologon"
        Write-BoxstarterMessage 'Logon Set'
    }
}
