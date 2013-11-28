function Cleanup-Boxstarter {
    param([switch]$KeepWindowOpen)
    if(Get-IsRemote){ 
        Remove-BoxstarterTask
    }
    Start-UpdateServices

    if(Test-Path "$(Get-BoxstarterTempDir)\BoxstarterReEnableUAC") {
        del "$(Get-BoxstarterTempDir)\BoxstarterReEnableUAC"
        Enable-UAC
    }
    if(!$Boxstarter.IsRebooting) { 
        $startup = "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup"
        if( Test-Path "$Startup\boxstarter-post-restart.bat") {
            remove-item "$Startup\boxstarter-post-restart.bat"
            remove-item "$(Get-BoxstarterTempDir)\Boxstarter.Script"
            $promptToExit=$true
        }
        $winLogonKey="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        $winlogonProps = Get-ItemProperty -Path $winLogonKey
        if($winlogonProps.DefaultUserName){Remove-ItemProperty -Path $winLogonKey -Name "DefaultUserName" -ErrorAction SilentlyContinue}
        if($winlogonProps.DefaultDomainName){Remove-ItemProperty -Path $winLogonKey -Name "DefaultDomainName" -ErrorAction SilentlyContinue}
        if($winlogonProps.DefaultPassword){Remove-ItemProperty -Path $winLogonKey -Name "DefaultPassword" -ErrorAction SilentlyContinue}
        if($winlogonProps.AutoAdminLogon){Remove-ItemProperty -Path $winLogonKey -Name "AutoAdminLogon" -ErrorAction SilentlyContinue}
        Write-Debug "Cleaned up logon registry and restart file"
        if($promptToExit -or $KeepWindowOpen){
            Read-Host 'Type ENTER to exit'
        }
        return
    } 

    if(!(Get-IsRemote)){
        if(Get-UAC){
            Write-BoxstarterMessage "UAC Enabled. Disabling..."
            Disable-UAC
            New-Item "$(Get-BoxstarterTempDir)\BoxstarterReEnableUAC" -type file | Out-Null
        }
    }

    if(!(Get-IsRemote) -and $BoxstarterPassword.Length -gt 0) {
        Write-BoxstarterMessage "Securely Storing $($env:userdomain)\$($Boxstarter.BoxstarterUser) credentials for automatic logon"
        Set-SecureAutoLogon $Boxstarter.BoxstarterUser $BoxstarterPassword $env:userdomain
        Write-BoxstarterMessage "Logon Set"
    }
}