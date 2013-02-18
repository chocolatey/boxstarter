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
    Write-BoxstarterMessage "Cleaned up logon registry and restart file"
    Start-UpdateServices
  } 
}