function cinst {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    chocolatey Install @args
}

function cup {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    chocolatey Update @args
}

function cinstm {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    chocolatey InstallMissing @args
}

function chocolatey {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    if(Test-PendingReboot) {return Invoke-Reboot}
    Call-Chocolatey @args
}

function Call-Chocolatey {
    ."$env:ChocolateyInstall\chocolateyinstall\chocolatey.ps1" @args
}