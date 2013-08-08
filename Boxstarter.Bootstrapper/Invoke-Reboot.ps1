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
One can use the $Boxstarter variable's RebootOk to enable/disable
reboots. If this is set to $False (the default) then Invoke-Reboot
will not do anything. If Boxstarter was invoked with the -Rebootok
parameter $Boxstarter.RebootOk is set to True.

.LINK
http://boxstarter.codeplex.com
Test-PendingReeboot
Invoke-Boxstarter
about_boxstarter_bootstrapper
about_boxstarter_variable_in_bootstrapper
#>
    if(!$Boxstarter.RebootOk) { 
        Write-BoxstarterMessage "A Reboot was requested but Reboots are surpressed. Either call Invoke-Boxstarter with -RebootOk or set `$Boxstarter.RebootOk to `$true"
        return 
    }
    Write-BoxstarterMessage "writing restart file"
    New-Item "$(Get-BoxstarterTempDir)\Boxstarter.script" -type file -value $boxstarter.ScriptToCall -force | Out-Null
    $startup = "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup"
    $restartScript="Call powershell -NoProfile -ExecutionPolicy bypass -command `"Import-Module '$($Boxstarter.BaseDir)\Boxstarter.Bootstrapper\boxstarter.bootstrapper.psd1';Invoke-Boxstarter -RebootOk`""
    New-Item "$startup\boxstarter-post-restart.bat" -type file -force -value $restartScript | Out-Null
    $Boxstarter.IsRebooting=$true
    Restart
}

function Restart {
    exit
}
