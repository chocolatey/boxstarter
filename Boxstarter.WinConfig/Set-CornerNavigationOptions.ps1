function Set-CornerNavigationOptions {
<#
.SYNOPSIS
Sets options for the Windows Corner Navigation

.PARAMETER EnableUpperRightCornerShowCharms
When I point to the upper-right corner, show the charms

.PARAMETER DisableUpperRightCornerShowCharms
Disables the showing of charms when pointing to the upper right corner, see EnableUpperRightCornerShowCharms

.PARAMETER EnableUpperLeftCornerSwitchApps
When I click the upper-left corner, switch between my recent apps

.PARAMETER DisableUpperLeftCornerSwitchApps
Disables the switching between recent apps, when clicking in the upper-left corner, see EnableUpperLeftCornerSwitchApps

.PARAMETER EnableUsePowerShellOnWinX
Replace Command Prompt with Windows PowerShell in the menu when I right-click the lower-left corner or press Windows key+X

.PARAMETER DisableUsePowerShellOnWinX
Disables the showing of Windows PowerShell in the lower-left corner, see EnableUsePowerShellOnWinX
#>
	[CmdletBinding()]
	param(
		[switch]$EnableUpperRightCornerShowCharms,
		[switch]$DisableUpperRightCornerShowCharms,
		[switch]$EnableUpperLeftCornerSwitchApps,
		[switch]$DisableUpperLeftCornerSwitchApps,
		[switch]$EnableUsePowerShellOnWinX,
		[switch]$DisableUsePowerShellOnWinX
	)

	$PSBoundParameters.Keys | % {
        if($_-like "En*"){ $other="Dis" + $_.Substring(2)}
        if($_-like "Dis*"){ $other="En" + $_.Substring(3)}
        if($PSBoundParameters[$_] -and $PSBoundParameters[$other]) {
            throw new-Object -TypeName ArgumentException "You may not set both $_ and $other. You can only set one."
        }
    }

	$edgeUIKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ImmersiveShell\EdgeUi'
	$advancedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

	if(Test-Path -Path $edgeUIKey) {
		if($EnableUpperRightCornerShowCharms) { Set-ItemProperty -Path $edgeUIKey -Name 'DisableTRCorner' -Value 0 }
		if($DisableUpperRightCornerShowCharms) { Set-ItemProperty -Path $edgeUIKey -Name 'DisableTRCorner' -Value 1 }

		if($EnableUpperLeftCornerSwitchApps) { Set-ItemProperty -Path $edgeUIKey -Name 'DisableTLCorner' -Value 0 }
		if($DisableUpperLeftCornerSwitchApps) { Set-ItemProperty -Path $edgeUIKey -Name 'DisableTLCorner' -Value 1 }
	}

	if(Test-Path -Path $advancedKey) {
		if($EnableUsePowerShellOnWinX) { Set-ItemProperty -Path $advancedKey -Name 'DontUsePowerShellOnWinX' -Value 0 }
		if($DisableUsePowerShellOnWinX) { Set-ItemProperty -Path $advancedKey -Name 'DontUsePowerShellOnWinX' -Value 1 }
    }
}
