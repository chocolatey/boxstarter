function Set-StartScreenOptions {
<#
.SYNOPSIS
Sets options for the Windows Start Screen.

.PARAMETER enableBootToDesktop
When I sign in or close all apps on a screen, go to the desktop instead of Start

.PARAMETER disableBootToDesktop
Disables the Boot to Desktop Option, see enableBootToDesktop

.PARAMETER enableShowStartOnActiveScreen
Show Start on the display I'm using when I press the Windows logo key

.PARAMETER disableShowStartOnActiveScreen
Disables the displaying of the Start screen on active screen, see enableShowStartOnActiveScreen

.PARAMETER enableShowAppsViewOnStartScreen
Show the Apps view automatically when I go to Start

PARAMETER disableShowAppsViewOnStartScreen
Disables the showing of Apps View when Start is activated, see enableShowAppsViewOnStartScreen

.PARAMETER enableSearchEverywhereInAppsView
Search everywhere instead of just my apps when I search from the Apps View

.PARAMETER disableSearchEverywhereInAppsView
Disables the searching of everywhere instead of just apps, see enableSearchEverywhereInAppsView

.PARAMETER enableListDesktopAppsFirst
List desktop apps first in the Apps view when it's sorted by category

.PARAMETER disableListDesktopAppsFirst
Disables the ability to list desktop apps first when sorted by category, see enableListDesktopAppsFirst

.LINK
http://boxstarter.codeplex.com

#>    

	param(
		[switch]$enableBootToDesktop,
		[switch]$disableBootToDesktop,
		[switch]$enableShowStartOnActiveScreen,
		[switch]$disableShowStartOnActiveScreen,
		[switch]$enableShowAppsViewOnStartScreen,
		[switch]$disableShowAppsViewOnStartScreen,
		[switch]$enableSearchEverywhereInAppsView,
		[switch]$disableSearchEverywhereInAppsView,
		[switch]$enableListDesktopAppsFirst,
		[switch]$disableListDesktopAppsFirst
	)

	$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartPage'

	if(Test-Path -Path $key) {
		if($enableBootToDesktop) { Set-ItemProperty -Path $key -Name 'OpenAtLogon' -Value 0 }
		if($disableBootToDesktop) { Set-ItemProperty -Path $key -Name 'OpenAtLogon' -Value 1 }

		if($enableShowStartOnActiveScreen) { Set-ItemProperty -Path $key -Name 'MonitorOverride' -Value 1 }
		if($disableShowStartOnActiveScreen) { Set-ItemProperty -Path $key -Name 'MonitorOverride' -Value 0 }

		if($enableShowAppsViewOnStartScreen) { Set-ItemProperty -Path $key -Name 'MakeAllAppsDefault' -Value 1 }
		if($disableShowAppsViewOnStartScreen) { Set-ItemProperty -Path $key -Name 'MakeAllAppsDefault' -Value 0 }

		if($enableSearchEverywhereInAppsView) { Set-ItemProperty -Path $key -Name 'GlobalSearchInApps' -Value 1 }
		if($disableSearchEverywhereInAppsView) { Set-ItemProperty -Path $key -Name 'GlobalSearchInApps' -Value 0 }

		if($enableListDesktopAppsFirst) { Set-ItemProperty -Path $key -Name 'DesktopFirst' -Value 1 }
		if($disableListDesktopAppsFirst) { Set-ItemProperty -Path $key -Name 'DesktopFirst' -Value 0 }
	}
}