function Invoke-Reboot {
<#
.SYNOPSIS
Reboots the local machine ensuring Boxstarter restarts 
automatically after reboot and sets up autologin if it a 
password was provided.

.DESCRIPTION
Use this command inside of a boxstarter package instead 
of calling Restart-Computer

This command eill often be used with the Test-PendingReboot
command. If Test-PendingReboot returns true, one may want 
to call Invoke-Reboot to restart otherwise the remainder of 
the package might fail.

.LINK
Test-PendingReeboot

#>
    New-Item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat" -type file -force -value "$baseDir\BoxStarter.bat $bootstrapPackage" | Out-Null
    if($password.Length -gt 0) {
        Set-SecureAutoLogon $env:username $password $env:userdomain
    }
    $script:boxstarterRebooting=$true
    Restart
}

function Restart {
    Restart-Computer -force
}
