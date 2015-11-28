try {
    Remove-Item "c:\ProgramData\Chocolatey\lib\force-reboot" -Recurse -ErrorAction SilentlyContinue

    Write-boxstartermessage "installing test package"
    cinst force-reboot

    if($PSVersionTable.PSVersion -gt '2.0.0' -and ([bool]::Parse($env:IsRemote))) {
        if(Test-Path "c:\ProgramData\Chocolatey\lib\windirstat") {
            cuninst windirstat -y
        }
        cinst windirstat
    }
    New-Item -Path "$($boxstarter.BaseDir)\test_marker" -ItemType File -force
}
catch {
    $_ | Out-File "$($boxstarter.BaseDir)\test_error.txt" -Append
}
