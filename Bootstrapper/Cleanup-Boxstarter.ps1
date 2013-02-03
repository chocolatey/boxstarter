function Cleanup-Boxstarter {
  if(!$boxstarterRebooting) { 
    if( Test-Path "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat") {
        remove-item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat"
    }
    $winLogonKey="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Remove-ItemProperty -Path $winLogonKey -Name "DefaultUserName" -ErrorAction Ignore
    Remove-ItemProperty -Path $winLogonKey -Name "DefaultDomainName" -ErrorAction Ignore
    Remove-ItemProperty -Path $winLogonKey -Name "DefaultPassword" -ErrorAction Ignore
    Remove-ItemProperty -Path $winLogonKey -Name "AutoAdminLogon" -ErrorAction Ignore
    Start-UpdateServices
  } 
}