function Cleanup-Boxstarter {
    if(!$Boxstarter.IsRebooting) { 
        $startup = "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup"
        if( Test-Path "$Startup\boxstarter-post-restart.bat") {
            remove-item "$Startup\boxstarter-post-restart.bat"
            remove-item "$env:temp\Boxstarter.Script"
        }
        $winLogonKey="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        Remove-ItemProperty -Path $winLogonKey -Name "DefaultUserName" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $winLogonKey -Name "DefaultDomainName" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $winLogonKey -Name "DefaultPassword" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $winLogonKey -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
        Write-Debug "Cleaned up logon registry and restart file"
        Start-UpdateServices
        return
    } 

    if($BoxstarterPassword.Length -gt 0 -or $Boxstarter.AutologedOn) {
        if(Get-UAC){
            Write-BoxstarterMessage "UAC Enabled. Disabling..."
            Disable-UAC
            New-Item "$env:temp\BoxstarterReEnableUAC" -type file | Out-Null
        }
    }
    if($BoxstarterPassword.Length -gt 0) {
        Write-BoxstarterMessage "Securely Storing $($env:userdomain)\$($BoxstarterUser) credentials for automatic logon"
        Set-SecureAutoLogon $BoxstarterUser $BoxstarterPassword $env:userdomain
        Write-BoxstarterMessage "Logon Set"
    }
}