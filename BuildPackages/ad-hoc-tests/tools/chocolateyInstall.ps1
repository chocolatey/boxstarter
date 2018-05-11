if(!(Test-Path "$home\test1.txt")) {
    new-Item $home\test1.txt -value "hi1" -type file
    write-host "reboot 1"
    return Invoke-Reboot
}
if(!(Test-Path "$home\test2.txt")) {
    new-Item $home\test2.txt -value "hi1" -type file
    write-host "reboot 2"
    return Invoke-Reboot
}
write-host "I am done"
del $home\test*
