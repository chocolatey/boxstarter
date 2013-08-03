if(!(Test-Path "$home\test1.txt")) {
    new-Item $home\test1.txt -value "hi1" -type file
    return Invoke-Reboot
}
if(!(Test-Path "$home\test2.txt")) {
    new-Item $home\test2.txt -value "hi1" -type file
    return Invoke-Reboot
}
write-host "I am done"
del $home\test*