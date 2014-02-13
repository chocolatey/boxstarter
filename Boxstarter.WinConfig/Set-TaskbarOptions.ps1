function Set-TaskbarOptions {
<#
.SYNOPSIS
Sets options for the Windows Task Bar

.PARAMETER EnableMakeTaskbarSmall
Makes the Windows Task Bar skinny

.PARAMETER DisableMakeTaskbarSmall
Makes the Windows Task Bar not as skinny, see EnableMakeTaskbarSmall

.PARAMETER EnableLockTheTaskbar
Enables the locking of the Windows Task Bar

.PARAMETER DisableLockTheTaskbar
Disables the locking of the Windows Task Bar, see EnableLockTheTaskbar

.PARAMETER DockTaskbarTop
Docks the Windows Taskbar to the top of the screen

.PARAMETER DockTaskbarLeft
Docks the Windows Taskbar to the left hand side of the screen

.PARAMETER DockTaskbarBottom
Docks the Windows Taskbar to the bottom of the screen

.PARAMETER DockTaskbarRight
Docks the Windows Taskbar to the right hand side of the screen

#>
	[CmdletBinding()]
	param(
		[switch]$EnableMakeTaskbarSmall,
		[switch]$DisableMakeTaskbarSmall,
		[switch]$EnableLockTheTaskbar,
		[switch]$DisableLockTheTaskbar,
		[switch]$DockTaskbarTop,
		[switch]$DockTaskbarLeft,
		[switch]$DockTaskbarBottom,
		[switch]$DockTaskbarRight
	)

	$PSBoundParameters.Keys | % {
		$checkDuplicateOfEnableDisable = $false;
		$checkDuplicateOfDock = $false;

        if($_-like "En*"){ $other="Dis" + $_.Substring(2); $checkDuplicateOfEnableDisable = $true; }
        if($_-like "Dis*"){ $other="En" + $_.Substring(3); $checkDuplicateOfEnableDisable = $true; }

		if($_-like "*Top"){ $firstSide=$_.TrimEnd("Top") + "Left"; $secondSide=$_.TrimEnd("Top") + "Bottom"; $thirdSide=$_.TrimEnd("Top") + "Right"; $checkDuplicateOfDock = $true; }
        if($_-like "*Left"){ $firstSide=$_.TrimEnd("Left") + "Top"; $secondSide=$_.TrimEnd("Left") + "Bottom"; $thirdSide=$_.TrimEnd("Left") + "Right"; $checkDuplicateOfDock = $true; }
		if($_-like "*Bottom"){ $firstSide=$_.TrimEnd("Bottom") + "Top"; $secondSide=$_.TrimEnd("Bottom") + "Left"; $thirdSide=$_.TrimEnd("Bottom") + "Right"; $checkDuplicateOfDock = $true; }
		if($_-like "*Right"){ $firstSide=$_.TrimEnd("Right") + "Top"; $secondSide=$_.TrimEnd("Right") + "Left"; $thirdSide=$_.TrimEnd("Right") + "Bottom"; $checkDuplicateOfDock = $true; }

		if($checkDuplicateOfDock) {
			if($PSBoundParameters[$_] -and ($PSBoundParameters[$firstSide] -or $PSBoundParameters[$secondSide] -or $PSBoundParameters[$thirdSide])) {
				throw new-Object -TypeName ArgumentException "You may not set both more than one docking option at once."
			}
		}

		if($checkDuplicateOfEnableDisable) {
			if($PSBoundParameters[$_] -and $PSBoundParameters[$other]) {
				throw new-Object -TypeName ArgumentException "You may not set both $_ and $other. You can only set one."
			}
		}
    }

	$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
	$dockingKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects2'

	if(Test-Path -Path $key) {
		if($EnableMakeTaskbarSmall) { Set-ItemProperty $key TaskbarSmallIcons 1 }
		if($DisableMakeTaskbarSmall) { Set-ItemProperty $key TaskbarSmallIcons 0 }

		if($EnableLockTheTaskbar) { Set-ItemProperty $key TaskbarSizeMove 0 }
		if($DisableLockTheTaskbar) { Set-ItemProperty $key TaskbarSizeMove 1 }

		Restart-Explorer
	}

	if(Test-Path -Path $dockingKey) {
		if($DockTaskbarTop) { Set-ItemProperty -Path $dockingKey -Name Settings -Value ([byte[]] (0x28,0x00,0x00,0x00,0xff,0xff,0xff,0xff,0x02,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x3e,0x00,0x00,0x00,0x2e,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x80,0x07,0x00,0x00,0x2e,0x00,0x00,0x00)) }
		if($DockTaskbarLeft) { Set-ItemProperty -Path $dockingKey -Name Settings -Value ([byte[]] (0x28,0x00,0x00,0x00,0xff,0xff,0xff,0xff,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x3e,0x00,0x00,0x00,0x2e,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x3e,0x00,0x00,0x00,0xb0,0x04,0x00,0x00)) }
		if($DockTaskbarBottom) { Set-ItemProperty -Path $dockingKey -Name Settings -Value ([byte[]] (0x28,0x00,0x00,0x00,0xff,0xff,0xff,0xff,0x02,0x00,0x00,0x00,0x03,0x00,0x00,0x00,0x3e,0x00,0x00,0x00,0x2e,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x82,0x04,0x00,0x00,0x80,0x07,0x00,0x00,0xb0,0x04,0x00,0x00)) }
		if($DockTaskbarRight) { Set-ItemProperty -Path $dockingKey -Name Settings -Value ([byte[]] (0x28,0x00,0x00,0x00,0xff,0xff,0xff,0xff,0x02,0x00,0x00,0x00,0x02,0x00,0x00,0x00,0x3e,0x00,0x00,0x00,0x2e,0x00,0x00,0x00,0x42,0x07,0x00,0x00,0x00,0x00,0x00,0x00,0x80,0x07,0x00,0x00,0xb0,0x04,0x00,0x00)) }

		Restart-Explorer
	}
}