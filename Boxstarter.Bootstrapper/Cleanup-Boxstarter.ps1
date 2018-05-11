function Cleanup-Boxstarter {
    param(
        [switch]$KeepWindowOpen,
        [switch]$DisableRestart)
    if(Get-IsRemote){
        Remove-BoxstarterTask
    }
    Start-UpdateServices

    if(Test-Path "$(Get-BoxstarterTempDir)\BoxstarterReEnableUAC") {
        del "$(Get-BoxstarterTempDir)\BoxstarterReEnableUAC"
        Enable-UAC
    }
    if(!$Boxstarter.IsRebooting) {
        Write-BoxstarterMessage "Cleaning up and not rebooting" -Verbose
        $startup = "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup"
        if( Test-Path "$Startup\boxstarter-post-restart.bat") {
            Write-BoxstarterMessage "Cleaning up restart file" -Verbose
            remove-item "$Startup\boxstarter-post-restart.bat"
            remove-item "$(Get-BoxstarterTempDir)\Boxstarter.Script"
            $promptToExit=$true
        }
        if(Test-Path "$(Get-BoxstarterTempDir)\Boxstarter.autologon") {
            Write-BoxstarterMessage "Cleaning up autologon registry keys" -Verbose
            $winLogonKey="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
            $winlogonProps = Import-CLIXML -Path "$(Get-BoxstarterTempDir)\Boxstarter.autologon"
            @("DefaultUserName","DefaultDomainName","DefaultPassword","AutoAdminLogon") | % {
                if(!$winlogonProps.ContainsKey($_)){
                  Remove-ItemProperty -Path $winLogonKey -Name $_ -ErrorAction SilentlyContinue
                }
                else {
                  Set-ItemProperty -Path $winLogonKey -Name $_ -Value $winlogonProps[$_]
                }
            }
            Remove-Item -Path "$(Get-BoxstarterTempDir)\Boxstarter.autologon"
        }
        if($promptToExit -or $KeepWindowOpen){
            Read-Host 'Type ENTER to exit'
        }
        return
    }

    if(!(Get-IsRemote -PowershellRemoting) -and !$DisableRestart){
        if(Get-UAC){
            Write-BoxstarterMessage "UAC Enabled. Disabling..."
            Disable-UAC
            New-Item "$(Get-BoxstarterTempDir)\BoxstarterReEnableUAC" -type file | Out-Null
        }
    }

    if(!(Get-IsRemote -PowershellRemoting) -and $BoxstarterPassword.Length -gt 0) {
        $currentUser=Get-CurrentUser
        Write-BoxstarterMessage "Securely Storing $($currentUser.Domain)\$($currentUser.Name) credentials for automatic logon"
        Set-SecureAutoLogon $currentUser.Name $BoxstarterPassword $currentUser.Domain -BackupFile "$(Get-BoxstarterTempDir)\Boxstarter.autologon"
        Write-BoxstarterMessage "Logon Set"
    }
}
