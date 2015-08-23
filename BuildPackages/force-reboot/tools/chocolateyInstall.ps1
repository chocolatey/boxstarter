$rebootFile = "$($boxstarter.BaseDir)\reboot-test.txt"

if(!(Test-Path $rebootFile)) {
    new-Item $rebootFile -value "hi1" -type file
    write-host "rebooting"
    return Invoke-Reboot
}
write-host "I am done"
del $rebootFile