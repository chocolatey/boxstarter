if(!(Test-Path "$home\test1.txt")) {
    new-Item $home\test1.txt -value "hi1" -type file
    Write-Host "reboot 1"
    return Invoke-Reboot
}
if(!(Test-Path "$home\test2.txt")) {
    new-Item $home\test2.txt -value "hi1" -type file
    Write-Host "reboot 2"
    return Invoke-Reboot
}
Write-Host "I am done"
del $home\test*
