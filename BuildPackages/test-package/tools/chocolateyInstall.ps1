try {
    if(Test-Path "c:\ProgramData\Chocolatey\lib\force-reboot"){
        Remove-Item "c:\ProgramData\Chocolatey\lib\force-reboot" -Recurse
    }

    Write-boxstartermessage "installing test package"
    choco install TelnetClient -source WindowsFeatures
    choco install force-reboot

    if($PSVersionTable.PSVersion -gt '2.0.0' -and ([bool]::Parse($env:IsRemote))) {
        cinst windirstat
    }
    New-Item -Path "$($boxstarter.BaseDir)\test_marker" -ItemType File -force
}
catch {
    $_ | Out-File "$($boxstarter.BaseDir)\test_error.txt" -Append
}
