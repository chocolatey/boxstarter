function Set-NotificationAreaOptions {
<#
.SYNOPSIS
Sets options for the Windows Notification Area

.PARAMETER AlwaysShowIconsOn
Turn on always show all icons in the notification area
.PARAMETER AlwaysShowIconsOff
Turn off always show all icons in the notification area
#>

	[CmdletBinding()]
	param(
		[switch]$AlwaysShowIconsOn,
		[switch]$AlwaysShowIconsOff
	)

	$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
	$AlwaysShowIconsKey = "$key"

	if(Test-Path -Path $AlwaysShowIconsKey) {
		if($AlwaysShowIconsOn) { Set-ItemProperty -Path $AlwaysShowIconsKey -Name 'EnableAutoTray' -Value 0 }
		if($AlwaysShowIconsOff) { Set-ItemProperty -Path $AlwaysShowIconsKey -Name 'EnableAutoTray' -Value 1 }
	}
}
