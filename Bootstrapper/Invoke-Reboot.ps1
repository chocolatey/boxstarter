function Invoke-Reboot {
    New-Item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat" -type file -force -value "$baseDir\BoxStarter.bat $bootstrapPackage"
    if($password.Length -gt 0) {
        Set-SecureAutoLogon $env:username $password $env:userdomain
    }
    $boxstarterRebooting=$true
    Restart
}

function Restart {
    Restart-Computer -force
}
