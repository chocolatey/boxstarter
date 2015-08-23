Write-boxstartermessage "installing test package"

cinst force-reboot

New-Item -Path "$($boxstarter.BaseDir)\test_marker" -ItemType File