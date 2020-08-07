<#
.SYNOPSIS
Disables the Bing Internet Search when using the search field in the Taskbar or Start Menu.

.DESCRIPTION
Disables the Bing Internet Search when using the search field in the Taskbar or Start Menu.

This is usable on all Windows versions pre and post Windows 2004 release (OS version 10.0.19041).

.NOTES
Boxstarter (https://boxstarter.org) (c) 2018 Chocolatey Software, Inc, 2012 - 2018 Matt Wrock.

.LINK
https://boxstarter.org
https://www.privateinternetaccess.com/forum/discussion/18301/how-to-uninstall-core-apps-in-windows-10-and-miscellaneous
https://www.lifehacker.com.au/2020/06/how-to-disable-bing-search-in-windows-10s-start-menu-2/

#>
function Disable-BingSearch {
    [CmdletBinding()]
    Param()

    $path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'
    $windows2004AndLaterPath = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
    $windows2004Version = '10.0.19041'

    $osVersion = (Get-CimInstance -ClassName Win32_OperatingSystem).Version
    if ([version]$osVersion -ge [version]$windows2004Version) {
        if (-not (Test-Path -Path $windows2004AndLaterPath)) {
            $null = New-Item -Path $windows2004AndLaterPath
        }

        $null = New-ItemProperty -Path $windows2004AndLaterPath -Name 'DisableSearchBoxSuggestions' -Value 1 -PropertyType 'DWORD'
    }
    else {
        if( -not (Test-Path -Path $path)) {
            $null = New-Item -Path $path
        }

        $null = New-ItemProperty -Path $path -Name "BingSearchEnabled" -Value 0 -PropertyType "DWORD"
    }
}
