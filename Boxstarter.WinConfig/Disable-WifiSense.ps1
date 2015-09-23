function Disable-WifiSense {
<#
.SYNOPSIS
Disables the Windows 10 Wifi Sense feature.

.LINK
http://boxstarter.org
http://windowsitpro.com/windows-10/disabling-windows-10s-wi-fi-sense-business-devices

#>
    $path = "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config"
    if(!(Test-Path $path)) {
        New-Item $path
    }

    New-ItemProperty -LiteralPath $path -Name "AutoConnectAllowedOEM" -Value 0 -PropertyType "DWord" -ErrorAction SilentlyContinue
    Set-ItemProperty -LiteralPath $path -Name "AutoConnectAllowedOEM" -Value 0
}
