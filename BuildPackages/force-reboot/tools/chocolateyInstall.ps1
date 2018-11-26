try {
    $rebootFile = "$($boxstarter.BaseDir)\reboot-test.txt"

    if(!(Test-Path $rebootFile)) {
        New-Item $rebootFile -value "hi1" -type file
        Write-Host "rebooting"
        return Invoke-Reboot
    }
    Write-Host "I am done"
    del $rebootFile
}
catch {
    $_ | Out-File "$($boxstarter.BaseDir)\test_error.txt" -Append
}
