function Set-UpdatesDeliveryMode {
<#
.SYNOPSIS
Sets the mode in which Updates are delivered. Allows to set the Update Bandwith Sharing option.

.PARAMETER DeliveryMode
Specifies whether updates are coming from additional sources in addition to Microsoft.
Valid inputs are:
    * Off: Updates are only coming from Microsofts servers.
    * LocalNetwork: Updates are coming from Microsoft and additionally, updates are received and also delivered to other PCs in the local network.
    * Internet: Updates are coming from Microsoft and additionally, updates are received and also delivered to other PCs in the local network or on the internet.

#>
    param(
        [ValidateSet('Off','LocalNetwork','Internet')]
		$DeliveryMode
    )
    $path1 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config"
    $path2 = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization"
    if(!(Test-Path $path1)) {
        New-Item $path1
    }
    if(!(Test-Path $path2)) {
        New-Item $path2
    }

    switch($DeliveryMode) {
        "Off" { $value = 0 }
        "LocalNetwork" { $value = 1 }
        "Internet" { $value = 3 }
    }

    New-ItemProperty -LiteralPath $path1 -Name "DODownloadMode" -Value $value -PropertyType "DWord" -ErrorAction SilentlyContinue
    Set-ItemProperty -LiteralPath $path1 -Name "DODownloadMode" -Value $value
    # Unclear if we need that one as well. Test showed that not, but unclear of the consequences of diverging values
    New-ItemProperty -LiteralPath $path2 -Name "SystemSettingsDownloadMode" -Value $value -PropertyType "DWord" -ErrorAction SilentlyContinue
    Set-ItemProperty -LiteralPath $path2 -Name "SystemSettingsDownloadMode" -Value $value
}
