function Disable-GameBarTips {
<#
.SYNOPSIS
Turns off the tips displayed by the XBox GameBar

.LINK
https://boxstarter.org

#>
    $path = "HKCU:\SOFTWARE\Microsoft\GameBar"
    if(!(Test-Path $path)) {
        New-Item $path
    }

    New-ItemProperty -LiteralPath $path -Name "ShowStartupPanel" -Value 0 -PropertyType "DWord" -ErrorAction SilentlyContinue
    Set-ItemProperty -LiteralPath $path -Name "ShowStartupPanel" -Value 0

    Write-Output "GameBar Tips have been disabled."
}
