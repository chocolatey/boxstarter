function Set-TaskbarOptions {
<#
.SYNOPSIS
Sets options for the Windows Task Bar

.PARAMETER Lock
Locks the taskbar

.PARAMETER UnLock
Unlocks the taskbar

.PARAMETER AutoHide
Autohides the taskbar

.PARAMETER NoAutoHide
No autohiding on the taskbar

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

.PARAMETER MultiMonitorOn
Turn on Show tasbkar on all displays.

.PARAMETER MultiMonitorOff
Turn off Show taskbar on all displays.

.PARAMETER MultiMonitorMode
Changes the behavior of the Taskbar when using multiple displays.  Valid inputs are All, MainAndOpen, and Open.

.PARAMETER MultiMonitorCombine
Changes the Taskbar Icon combination style for non-primary displays.  Valid inputs are Always, Full, and Never.

#>
	[CmdletBinding(DefaultParameterSetName='unlock')]
	param(
        [Parameter(ParameterSetName='lockhide')]
        [Parameter(ParameterSetName='locknohide')]
        [switch]$Lock,
        [Parameter(ParameterSetName='unlock')]
        [Parameter(ParameterSetName='unlockhide')]
        [Parameter(ParameterSetName='unlocknohide')]
        [switch]$UnLock,
        [Parameter(ParameterSetName='lockhide')]
        [Parameter(ParameterSetName='unlockhide')]
        [switch]$AutoHide,
        [Parameter(ParameterSetName='locknohide')]
        [Parameter(ParameterSetName='unlocknohide')]
				[switch]$NoAutoHide,
				[Parameter(ParameterSetName='AlwaysShowIconsOn')]
				[switch]$AlwaysShowIconsOn,
				[Parameter(ParameterSetName='AlwaysShowIconsOff')]
				[switch]$AlwaysShowIconsOff,
				[ValidateSet('Small','Large')]
				$Size,
				[ValidateSet('Top','Left','Bottom','Right')]
				$Dock,
				[ValidateSet('Always','Full','Never')]
				$Combine,
        [Parameter(ParameterSetName='MultiMonitorOn')]
        [switch]$MultiMonitorOn,
        [Parameter(ParameterSetName='MultiMonitorOff')]
        [switch]$MultiMonitorOff,
        [ValidateSet('All', 'MainAndOpen', 'Open')]
        $MultiMonitorMode,
        [ValidateSet('Always','Full','Never')]
        $MultiMonitorCombine
    )

	$explorerKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
	$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
	$settingKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects2'
	
	if(-not (Test-Path -Path $settingKey)) {
		$settingKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
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

        if($MultiMonitorOn)
        {
            Set-ItemProperty $key MMTaskbarEnabled 1
        }

        if($MultiMonitorOff)
        {
            Set-ItemProperty $key MMTaskbarEnabled 0
        }

        switch($MultiMonitorMode) {
        "All" { Set-ItemProperty $key MMTaskbarMode 0 }
        "MainAndOpen" { Set-ItemProperty $key MMTaskbarMode 1 }
        "Open" {Set-ItemProperty $key MMTaskbarMode 2 }
        }
        
        switch($MultiMonitorCombine) {
            "Always" { Set-ItemProperty $key MMTaskbarGlomLevel 0 }
            "Full" { Set-ItemProperty $key MMTaskbarGlomLevel 1 }
            "Never" { Set-ItemProperty $key MMTaskbarGlomLevel 2 }
        }
    }

	if(Test-Path -Path $settingKey) {
		$settings = (Get-ItemProperty -Path $settingKey -Name Settings).Settings

		switch ($Dock) {
			"Top" { $settings[12] = 0x01 }
			"Left" { $settings[12] = 0x00 }
			"Bottom" { $settings[12] = 0x03 }
			"Right" { $settings[12] = 0x02 }
		}
		
		if($AutoHide){
			$settings[8] = $settings[8] -bor 1			
		}

		if($NoAutoHide){
			$settings[8] = $settings[8] -band 0
			Set-ItemProperty -Path $settingKey -Name Settings -Value $settings
		}
		
		Set-ItemProperty -Path $settingKey -Name Settings -Value $settings
	}

	if(Test-Path -Path $explorerKey) {
		if($AlwaysShowIconsOn) { Set-ItemProperty -Path $explorerKey -Name 'EnableAutoTray' -Value 0 }
		if($alwaysShowIconsOff) { Set-ItemProperty -Path $explorerKey -Name 'EnableAutoTray' -Value 1 }
	}
	Restart-Explorer
}
