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
		[ValidateSet('Small','Large')]
		$Size,
		[ValidateSet('Top','Left','Bottom','Right')]
		$Dock,
		[ValidateSet('Always','Full','Never')]
		$Combine
	)

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

		Restart-Explorer
	}

	if(Test-Path -Path $settingKey) {
		
		switch ($Dock) {
			"Top" { Set-ItemProperty -Path $settingKey -Name Settings -Value ([byte[]] (0x28,0x00,0x00,0x00,0xff,0xff,0xff,0xff,0x02,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x3e,0x00,0x00,0x00,0x2e,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x80,0x07,0x00,0x00,0x2e,0x00,0x00,0x00)) }
			"Left" { Set-ItemProperty -Path $settingKey -Name Settings -Value ([byte[]] (0x28,0x00,0x00,0x00,0xff,0xff,0xff,0xff,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x3e,0x00,0x00,0x00,0x2e,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x3e,0x00,0x00,0x00,0xb0,0x04,0x00,0x00)) }
			"Bottom" { Set-ItemProperty -Path $settingKey -Name Settings -Value ([byte[]] (0x28,0x00,0x00,0x00,0xff,0xff,0xff,0xff,0x02,0x00,0x00,0x00,0x03,0x00,0x00,0x00,0x3e,0x00,0x00,0x00,0x2e,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x82,0x04,0x00,0x00,0x80,0x07,0x00,0x00,0xb0,0x04,0x00,0x00)) }
			"Right" { Set-ItemProperty -Path $settingKey -Name Settings -Value ([byte[]] (0x28,0x00,0x00,0x00,0xff,0xff,0xff,0xff,0x02,0x00,0x00,0x00,0x02,0x00,0x00,0x00,0x3e,0x00,0x00,0x00,0x2e,0x00,0x00,0x00,0x42,0x07,0x00,0x00,0x00,0x00,0x00,0x00,0x80,0x07,0x00,0x00,0xb0,0x04,0x00,0x00)) }
		}

		$settings = (Get-ItemProperty -Path $settingKey -Name Settings).Settings
		
		if($AutoHide){
			$settings[8] = $settings[8] -bor 1
			Set-ItemProperty -Path $settingKey -Name Settings -Value $settings
		}

		if($NoAutoHide){
			$settings[8] = $settings[8] -band 0
			Set-ItemProperty -Path $settingKey -Name Settings -Value $settings
		}

		Restart-Explorer
	}
}
