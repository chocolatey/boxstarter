Write-boxstartermessage "installing test package"

cinst force-reboot

Remove-Item "c:\ProgramData\Chocolatey\lib\force-reboot" -Recurse
New-Item -Path "$($boxstarter.BaseDir)\test_marker" -ItemType File