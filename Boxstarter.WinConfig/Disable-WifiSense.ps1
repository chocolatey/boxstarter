function Disable-WifiSense {
<#
.SYNOPSIS
Disables the Windows 10 Wifi Sense feature.

.LINK
http://boxstarter.org
http://windowsitpro.com/windows-10/disabling-windows-10s-wi-fi-sense-business-devices
https://www.privateinternetaccess.com/forum/discussion/18301/how-to-uninstall-core-apps-in-windows-10-and-miscellaneous
https://gist.github.com/NickCraver/7ebf9efbfd0c3eab72e9
#>

    # different sources, different registry values that are being set. To be on the safe side, we set them ALL.
    $path1 = "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config"
    $path2 = "HKCU:\SOFTWARE\Microsoft\Siuf\Rules"
    $path3 = "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting"

    if(!(Test-Path $path1)) {
        New-Item $path1
    }

    if(!(Test-Path $path2)) {
        New-Item $path2
    }

    if(!(Test-Path $path3)) {
        New-Item $path3
    }

    New-ItemProperty -LiteralPath $path1 -Name "AutoConnectAllowedOEM" -Value 0 -PropertyType "DWord" -ErrorAction SilentlyContinue
    Set-ItemProperty -LiteralPath $path1 -Name "AutoConnectAllowedOEM" -Value 0
    New-ItemProperty -LiteralPath $path2 -Name "NumberOfSIUFInPeriod" -Value 0 -PropertyType "DWord" -ErrorAction SilentlyContinue
    Set-ItemProperty -LiteralPath $path2 -Name "NumberOfSIUFInPeriod" -Value 0
    New-ItemProperty -LiteralPath $path3 -Name "value" -Value 0 -PropertyType "DWord" -ErrorAction SilentlyContinue
    Set-ItemProperty -LiteralPath $path3 -Name "value" -Value 0
}
