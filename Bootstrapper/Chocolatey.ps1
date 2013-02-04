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
    if(Get-Module boxstarter.helpers){ #if helpers have not been loaded the UAC check at reboot will fail
        if(Test-PendingReboot) {return Invoke-Reboot}
    }
    Call-Chocolatey @args
}

function Call-Chocolatey {
    ."$env:ChocolateyInstall\chocolateyinstall\chocolatey.ps1" @args
}