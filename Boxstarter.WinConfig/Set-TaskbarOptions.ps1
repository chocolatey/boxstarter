function Set-TaskbarOptions {
<#
.SYNOPSIS
Sets options for the Windows Task Bar

.PARAMETER Lock
Locks the taskbar

.PARAMETER UnLock
Unlocks the taskbar

.PARAMETER Size
Changes the size of the Taskbar Icons.  Valid inputs are Small and Large.

.PARAMETER Dock
Changes the location in which the Taskbar is docked.  Valid inputs are Top, Left, Bottom and Right.

.PARAMETER Combine
Changes the Taskbar Icon combination style. Valid inputs are Always, Full, and Never.

.PARAMETER AlwaysShowIconsOn
Turn on always show all icons in the notification area

.PARAMETER AlwaysShowIconsOff
Turn off always show all icons in the notification area

#>
	[CmdletBinding(DefaultParameterSetName='unlock')]
	param(
        [Parameter(ParameterSetName='lock')]
        [switch]$Lock,
        [Parameter(ParameterSetName='unlock')]
        [switch]$UnLock,
		[Parameter(ParameterSetName='AlwaysShowIconsOn')]
		[switch]$AlwaysShowIconsOn,
		[Parameter(ParameterSetName='AlwaysShowIconsOff')]
		[switch]$AlwaysShowIconsOff,
		[ValidateSet('Small','Large')]
		$Size,
		[ValidateSet('Top','Left','Bottom','Right')]
		$Dock,
		[ValidateSet('Always','Full','Never')]
		$Combine
	)

	$explorerKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
	$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
	$dockingKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects2'

	if(-not (Test-Path -Path $dockingKey)) {
		$dockingKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
	}

	if(Test-Path -Path $key) {
		if($Lock)
		{
			Set-ItemProperty $key TaskbarSizeMove 0
        }
        if($UnLock){
			Set-ItemProperty $key TaskbarSizeMove 1
		}

		switch ($Size) {
			"Small" { Set-ItemProperty $key TaskbarSmallIcons 1 }
			"Large" { Set-ItemProperty $key TaskbarSmallIcons 0 }
		}

		switch($Combine) {
			"Always" { Set-ItemProperty $key TaskbarGlomLevel 0 }
			"Full" { Set-ItemProperty $key TaskbarGlomLevel 1 }
			"Never" { Set-ItemProperty $key TaskbarGlomLevel 2 }
		}

		Restart-Explorer
	}

	if(Test-Path -Path $dockingKey) {
		switch ($Dock) {
			"Top" { Set-ItemProperty -Path $dockingKey -Name Settings -Value ([byte[]] (0x28,0x00,0x00,0x00,0xff,0xff,0xff,0xff,0x02,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x3e,0x00,0x00,0x00,0x2e,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x80,0x07,0x00,0x00,0x2e,0x00,0x00,0x00)) }
			"Left" { Set-ItemProperty -Path $dockingKey -Name Settings -Value ([byte[]] (0x28,0x00,0x00,0x00,0xff,0xff,0xff,0xff,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x3e,0x00,0x00,0x00,0x2e,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x3e,0x00,0x00,0x00,0xb0,0x04,0x00,0x00)) }
			"Bottom" { Set-ItemProperty -Path $dockingKey -Name Settings -Value ([byte[]] (0x28,0x00,0x00,0x00,0xff,0xff,0xff,0xff,0x02,0x00,0x00,0x00,0x03,0x00,0x00,0x00,0x3e,0x00,0x00,0x00,0x2e,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x82,0x04,0x00,0x00,0x80,0x07,0x00,0x00,0xb0,0x04,0x00,0x00)) }
			"Right" { Set-ItemProperty -Path $dockingKey -Name Settings -Value ([byte[]] (0x28,0x00,0x00,0x00,0xff,0xff,0xff,0xff,0x02,0x00,0x00,0x00,0x02,0x00,0x00,0x00,0x3e,0x00,0x00,0x00,0x2e,0x00,0x00,0x00,0x42,0x07,0x00,0x00,0x00,0x00,0x00,0x00,0x80,0x07,0x00,0x00,0xb0,0x04,0x00,0x00)) }
		}

		Restart-Explorer
	}

	if(Test-Path -Path $explorerKey) {
		if($AlwaysShowIconsOn) { Set-ItemProperty -Path $explorerKey -Name 'EnableAutoTray' -Value 0 }
		if($alwaysShowIconsOff) { Set-ItemProperty -Path $explorerKey -Name 'EnableAutoTray' -Value 1 }
	}
}
