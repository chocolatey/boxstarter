function cinst {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    chocolatey Install @PSBoundParameters
}

function cup {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    chocolatey Update @PSBoundParameters
}

function cinstm {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    chocolatey InstallMissing @PSBoundParameters
}

function chocolatey {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>  
    if((Test-PendingReboot) -and $Boxstarter.RebootOk) {return Invoke-Reboot}
    Call-Chocolatey @PSBoundParameters
}

function Call-Chocolatey {
    ."$env:ChocolateyInstall\chocolateyinstall\chocolatey.ps1" @PSBoundParameters
}

function Intercept-Command ($commandName, $omitCommandParam) {
    $metadata=New-Object System.Management.Automation.CommandMetaData (Get-Command "$env:ChocolateyInstall\chocolateyinstall\chocolatey.ps1")
    $metadata.Parameters.Remove("Verbose") | out-null
    $metadata.Parameters.Remove("Debug") | out-null
    $metadata.Parameters.Remove("ErrorAction") | out-null
    $metadata.Parameters.Remove("WarningAction") | out-null
    $metadata.Parameters.Remove("ErrorVariable") | out-null
    $metadata.Parameters.Remove("WarningVariable") | out-null
    $metadata.Parameters.Remove("OutVariable") | out-null
    $metadata.Parameters.Remove("OutBuffer") | out-null
    if($omitCommandParam) {
        $metadata.Parameters.Remove("command") | out-null
    }
    $cmdLetBinding = [Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($metadata)
    $params = [Management.Automation.ProxyCommand]::GetParamBlock($metadata)
    $Content=Get-Content function:\$commandName
    Set-Item Function:\$commandName -value "$cmdLetBinding `r`n param ( $params )Process{ `r`n$Content}" -force
}

function Intrcept-Chocolatey {
    Intercept-Command cinst $true
    Intercept-Command cup $true
    Intercept-Command cinstm $true
    Intercept-Command chocolatey
    Intercept-Command call-chocolatey
}
