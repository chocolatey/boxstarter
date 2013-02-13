function Invoke-Reboot {
<#
.SYNOPSIS
Reboots the local machine ensuring Boxstarter restarts 
automatically after reboot and sets up autologin if it a 
password was provided.

.DESCRIPTION
Use this command inside of a boxstarter package instead 
of calling Restart-Computer

This command will often be used with the Test-PendingReboot
command. If Test-PendingReboot returns true, one may want 
to call Invoke-Reboot to restart otherwise the remainder of 
the package might fail.

.NOTES
Obe can use the $Boxstarter variable's RebootOk to enable/disable
reboots. If this is set to $False (the default) then Invoke-Reboot
will not do anything. If Boxstarter was invoked with the -Rebootok
parameter $Boxstarter.RebootOk is set to True.

.LINK
http://boxstarter.codeplex.com
Test-PendingReeboot
Invoke-Boxstarter
#>
    if(!$Boxstarter.RebootOk) { 
        Write-BoxstarterMessage "A Reboot was requested but Reboots are surpressed. Either call Invoke-Boxstarter with -RebootOk or set `$Boxstarter.RebootOk to `$true"
        return 
    }
    if($Boxstarter.LocalRepo){$commandArgs = "-LocalRepo `"$($Boxstarter.LocalRepo)`""}
    if($BoxstarterPassword.Length -gt 0 -or $Boxstarter.AutologedOn) {
        if(Get-UAC){
            Write-BoxstarterMessage "UAC Enabled. Disabling..."
            Disable-UAC
            $commandArgs += " -ReEnableUAC"
        }
    }
    if($BoxstarterPassword.Length -gt 0) {
        Write-BoxstarterMessage "Securely Storing $($env:userdomain)\$($BoxstarterUser) credentials for automatic logon"
        Set-SecureAutoLogon $BoxstarterUser $BoxstarterPassword $env:userdomain
    }
    Write-BoxstarterMessage "writing restart file"
    New-Item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat" -type file -force -value "Call `"$baseDir\BoxStarter.bat`" $($Boxstarter.package) -RebootOk $commandArgs `r`nPause" | Out-Null
    $script:boxstarterRebooting=$true
    Restart
}

function Restart {
    Write-BoxstarterMessage "Restarting..."
    Restart-Computer -force
}
