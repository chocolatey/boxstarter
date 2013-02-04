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
    if(!$Boxstarter.RebootOk) { 
        Write-Output "A Reboot was requested but Reboots are surpressed. Either call Invoke-Boxstarter with -RebootOk or set `$Boxstarter.RebootOk to `$true"
        return 
    }
    if($Boxstarter.LocalRepo){$commandArgs = "-LocalRepo `"$($Boxstarter.LocalRepo)`""}
    if($BoxstarterPassword.Length -gt 0) {
        if(Get-UAC){
            Disable-UAC
            $commandArgs += " -ReEnableUAC"
        }
        Write-Output "Securely Storing $($env:userdomain)\$($env:username) credentials for automatic logon"
        Set-SecureAutoLogon $env:username $BoxstarterPassword $env:userdomain
    }
    New-Item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat" -type file -force -value "$baseDir\BoxStarter.bat $($Boxstarter.package) -RebootOk $commandArgs" | Out-Null
    $script:boxstarterRebooting=$true
    Restart
}

function Restart {
    Restart-Computer -force
}
