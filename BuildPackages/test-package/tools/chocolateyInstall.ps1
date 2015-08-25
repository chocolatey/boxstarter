try {
    Remove-Item "c:\ProgramData\Chocolatey\lib\force-reboot" -Recurse -ErrorAction SilentlyContinue

    Write-boxstartermessage "installing test package"

    cinst force-reboot

    New-Item -Path "$($boxstarter.BaseDir)\test_marker" -ItemType File
}
catch {
    $_ | Out-File "$($boxstarter.BaseDir)\test_error.txt" -Append
}
