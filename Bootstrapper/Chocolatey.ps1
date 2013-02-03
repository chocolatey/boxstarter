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
    ."$env:ChocolateyInstall\chocolateyinstall\chocolatey.ps1" @args
}