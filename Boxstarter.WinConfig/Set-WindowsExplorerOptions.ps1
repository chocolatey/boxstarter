function Set-WindowsExplorerOptions {
<#
.SYNOPSIS
Sets options on the Windows Explorer shell

.PARAMETER EnableShowHiddenFilesFoldersDrives
If this flag is set, hidden files will be shown in Windows Explorer

.PARAMETER DisableShowHiddenFilesFoldersDrives
Disables the showing on hidden files in Windows Explorer, see EnableShowHiddenFilesFoldersDrives

.PARAMETER EnableShowProtectedOSFiles
If this flag is set, hidden Operating System files will be shown in Windows Explorer

.PARAMETER DisableShowProtectedOSFiles
Disables the showing of hidden Operating System Files in Windows Explorer, see EnableShowProtectedOSFiles

.PARAMETER EnableShowFileExtensions
Setting this switch will cause Windows Explorer to include the file extension in file names

.PARAMETER DisableShowFileExtensions
Disables the showing of file extension in file names, see EnableShowFileExtensions

.PARAMETER EnableShowFullPathInTitleBar
Setting this switch will cause Windows Explorer to show the full folder path in the Title Bar

.PARAMETER DisableShowFullPathInTitleBar
Disables the showing of the full path in Windows Explorer Title Bar, see EnableShowFullPathInTitleBar

.LINK
http://boxstarter.org

#>   

	[CmdletBinding()]
	param(
		[switch]$EnableShowHiddenFilesFoldersDrives,
		[switch]$DisableShowHiddenFilesFoldersDrives,
		[switch]$EnableShowProtectedOSFiles,
		[switch]$DisableShowProtectedOSFiles,
		[switch]$EnableShowFileExtensions,
		[switch]$DisableShowFileExtensions,
		[switch]$EnableShowFullPathInTitleBar,
		[switch]$DisableShowFullPathInTitleBar
	)

	$PSBoundParameters.Keys | % {
        if($_-like "En*"){ $other="Dis" + $_.Substring(2)}
        if($_-like "Dis*"){ $other="En" + $_.Substring(3)}
        if($PSBoundParameters[$_] -and $PSBoundParameters[$other]) {
            throw new-Object -TypeName ArgumentException "You may not set both $_ and $other. You can only set one."
        }
    }

	$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
    $advancedKey = "$key\Advanced"
	$cabinetStateKey = "$key\CabinetState"

    Write-BoxstarterMessage "Setting Windows Explorer options..."

	if(Test-Path -Path $advancedKey) {
		if($EnableShowHiddenFilesFoldersDrives) {Set-ItemProperty $advancedKey Hidden 1}
		if($DisableShowHiddenFilesFoldersDrives) {Set-ItemProperty $advancedKey Hidden 0}
		
		if($EnableShowFileExtensions) {Set-ItemProperty $advancedKey HideFileExt 0}
		if($DisableShowFileExtensions) {Set-ItemProperty $advancedKey HideFileExt 1}
		
		if($EnableShowProtectedOSFiles) {Set-ItemProperty $advancedKey ShowSuperHidden 1}
		if($DisableShowProtectedOSFiles) {Set-ItemProperty $advancedKey ShowSuperHidden 0}
		
		Restart-Explorer
	}

	if(Test-Path -Path $cabinetStateKey) {
		if($EnableShowFullPathInTitleBar) {Set-ItemProperty $cabinetStateKey FullPath  1}
		if($DisableShowFullPathInTitleBar) {Set-ItemProperty $cabinetStateKey FullPath  0}
		
		Restart-Explorer		
	}
}