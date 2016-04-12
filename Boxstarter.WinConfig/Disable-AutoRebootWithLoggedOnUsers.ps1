function Disable-AutoRebootWithLoggedOnUsers {
<#
.SYNOPSIS
Disables automatic reboots because of Windows Update when a user is logged on.

.LINK
http://boxstarter.org

#>
    $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if(!(Test-Path $path)) {
        New-Item $path
    }

    New-ItemProperty -LiteralPath $path -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -PropertyType "DWord" -ErrorAction SilentlyContinue
    Set-ItemProperty -LiteralPath $path -Name "NoAutoRebootWithLoggedOnUsers" -Value 1
}
