function Disable-BingSearch {
<#
.SYNOPSIS
Disables the Bing Internet Search when searching from the search field in the Taskbar or Start Menu.

.LINK
http://boxstarter.org
https://www.privateinternetaccess.com/forum/discussion/18301/how-to-uninstall-core-apps-in-windows-10-and-miscellaneous

#>
    $path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"

    if(!(Test-Path $path)) {
        New-Item $path
    }

    New-ItemProperty -LiteralPath $path -Name "BingSearchEnabled" -Value 0 -PropertyType "DWord" -ErrorAction SilentlyContinue
    Set-ItemProperty -LiteralPath $path -Name "BingSearchEnabled" -Value 0
}
