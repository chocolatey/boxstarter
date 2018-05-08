function Set-ExplorerOptions {
<#
.SYNOPSIS
Sets options on the windows Explorer shell

.PARAMETER showHiddenFilesFoldersDrives
If this switch is set, hidden files will be shown in windows explorer

.PARAMETER showProtectedOSFiles
If this flag is set, hidden Operating System files will be shown in windows explorer

.PARAMETER showFileExtensions
Setting this switch will cause windows explorer to include the file extension in file names

.LINK
https://boxstarter.org

#>
    param(
        [alias("showHidenFilesFoldersDrives")]
        [switch]$showHiddenFilesFoldersDrives,
        [switch]$showProtectedOSFiles,
        [switch]$showFileExtensions
    )

	Write-Warning "This command is deprecated, use Set-WindowsExplorerOptions instead."
	Write-Warning "Your call to this function will now be routed to the Set-WindowsExplorerOptions function."

	if($showHiddenFilesFoldersDrives) { Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives }
    if($showFileExtensions) { Set-WindowsExplorerOptions -EnableShowFileExtensions }
    if($showProtectedOSFiles) { Set-WindowsExplorerOptions -EnableShowProtectedOSFiles }
}
