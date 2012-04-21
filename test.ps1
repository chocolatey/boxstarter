
$scriptPath = (Split-Path -parent $MyInvocation.MyCommand.path)
. $scriptPath\utilities.ps1
Configure-ExplorerOptions -showHidenFilesFoldersDrives -showProtectedOSFiles -showFileExtensions
