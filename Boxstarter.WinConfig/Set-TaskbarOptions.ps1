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

#>
	[CmdletBinding()]
	param(
		[switch]$EnableMakeTaskbarSmall,
		[switch]$DisableMakeTaskbarSmall,
		[switch]$EnableLockTheTaskbar,
		[switch]$DisableLockTheTaskbar
	)

	$PSBoundParameters.Keys | % {
        if($_-like "En*"){ $other="Dis" + $_.Substring(2)}
        if($_-like "Dis*"){ $other="En" + $_.Substring(3)}
        if($PSBoundParameters[$_] -and $PSBoundParameters[$other]) {
            throw new-Object -TypeName ArgumentException "You may not set both $_ and $other. You can only set one."
        }
    }

	$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

	if(Test-Path -Path $key) {
		if($EnableMakeTaskbarSmall) { Set-ItemProperty $key TaskbarSmallIcons 1 }
		if($DisableMakeTaskbarSmall) { Set-ItemProperty $key TaskbarSmallIcons 0 }

		if($EnableLockTheTaskbar) { Set-ItemProperty $key TaskbarSizeMove 0 }
		if($DisableLockTheTaskbar) { Set-ItemProperty $key TaskbarSizeMove 1 }

		Restart-Explorer
	}
}