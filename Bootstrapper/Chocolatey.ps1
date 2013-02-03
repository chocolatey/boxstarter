function cinst {
    chocolatey Install @args
}

function cup {
    chocolatey Update @args
}

function cinstm {
    chocolatey InstallMissing @args
}

function chocolatey {
    if(Test-PendingReboot) {return Invoke-Reboot}
    Call-Chocolatey @args
}

function Call-Chocolatey {
    ."$env:ChocolateyInstall\chocolateyinstall\chocolatey.ps1" @args
}