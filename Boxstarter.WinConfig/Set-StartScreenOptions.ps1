function Set-StartScreenOptions {
<#
.SYNOPSIS
Sets options for the Windows Start Screen.

.PARAMETER EnableBootToDesktop
When I sign in or close all apps on a screen, go to the desktop instead of Start

.PARAMETER DisableBootToDesktop
Disables the Boot to Desktop Option, see enableBootToDesktop

.PARAMETER EnableDesktopBackgroundOnStart
Show Desktop background on Start

.PARAMETER DisableDesktopBackgroundOnStart
Do not show Desktop background on Start

.PARAMETER EnableShowStartOnActiveScreen
Show Start on the display I'm using when I press the Windows logo key

.PARAMETER DisableShowStartOnActiveScreen
Disables the displaying of the Start screen on active screen, see enableShowStartOnActiveScreen

.PARAMETER EnableShowAppsViewOnStartScreen
Show the Apps view automatically when I go to Start

.PARAMETER DisableShowAppsViewOnStartScreen
Disables the showing of Apps View when Start is activated, see enableShowAppsViewOnStartScreen

.PARAMETER EnableSearchEverywhereInAppsView
Search everywhere instead of just my apps when I search from the Apps View

.PARAMETER DisableSearchEverywhereInAppsView
Disables the searching of everywhere instead of just apps, see enableSearchEverywhereInAppsView

.PARAMETER EnableListDesktopAppsFirst
List desktop apps first in the Apps view when it's sorted by category

.PARAMETER DisableListDesktopAppsFirst
Disables the ability to list desktop apps first when sorted by category, see enableListDesktopAppsFirst

.LINK
https://boxstarter.org

#>
    [CmdletBinding()]
	param(
		[switch]$EnableBootToDesktop,
		[switch]$DisableBootToDesktop,
		[switch]$EnableDesktopBackgroundOnStart,
		[switch]$DisableDesktopBackgroundOnStart,
		[switch]$EnableShowStartOnActiveScreen,
		[switch]$DisableShowStartOnActiveScreen,
		[switch]$EnableShowAppsViewOnStartScreen,
		[switch]$DisableShowAppsViewOnStartScreen,
		[switch]$EnableSearchEverywhereInAppsView,
		[switch]$DisableSearchEverywhereInAppsView,
		[switch]$EnableListDesktopAppsFirst,
		[switch]$DisableListDesktopAppsFirst
	)

    $PSBoundParameters.Keys | %{
        if($_-like "En*"){ $other="Dis" + $_.Substring(2)}
        if($_-like "Dis*"){ $other="En" + $_.Substring(3)}
        if($PSBoundParameters[$_] -and $PSBoundParameters[$other]){
            throw new-Object -TypeName ArgumentException "You may not set both $_ and $other. You can only set one."
        }
    }

	$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
    $startPageKey = "$key\StartPage"
    $accentKey = "$key\Accent"

	if(Test-Path -Path $startPageKey) {
		if($enableBootToDesktop) { Set-ItemProperty -Path $startPageKey -Name 'OpenAtLogon' -Value 0 }
		if($disableBootToDesktop) { Set-ItemProperty -Path $startPageKey -Name 'OpenAtLogon' -Value 1 }

		if($enableShowStartOnActiveScreen) { Set-ItemProperty -Path $startPageKey -Name 'MonitorOverride' -Value 1 }
		if($disableShowStartOnActiveScreen) { Set-ItemProperty -Path $startPageKey -Name 'MonitorOverride' -Value 0 }

		if($enableShowAppsViewOnStartScreen) { Set-ItemProperty -Path $startPageKey -Name 'MakeAllAppsDefault' -Value 1 }
		if($disableShowAppsViewOnStartScreen) { Set-ItemProperty -Path $startPageKey -Name 'MakeAllAppsDefault' -Value 0 }

		if($enableSearchEverywhereInAppsView) { Set-ItemProperty -Path $startPageKey -Name 'GlobalSearchInApps' -Value 1 }
		if($disableSearchEverywhereInAppsView) { Set-ItemProperty -Path $startPageKey -Name 'GlobalSearchInApps' -Value 0 }

		if($enableListDesktopAppsFirst) { Set-ItemProperty -Path $startPageKey -Name 'DesktopFirst' -Value 1 }
		if($disableListDesktopAppsFirst) { Set-ItemProperty -Path $startPageKey -Name 'DesktopFirst' -Value 0 }
	}

	if(Test-Path -Path $accentKey) {
		if($EnableDesktopBackgroundOnStart) { Set-ItemProperty -Path $accentKey -Name 'MotionAccentId_v1.00' -Value 219 }
		if($DisableDesktopBackgroundOnStart) { Set-ItemProperty -Path $accentKey -Name 'MotionAccentId_v1.00' -Value 221 }
    }
}
