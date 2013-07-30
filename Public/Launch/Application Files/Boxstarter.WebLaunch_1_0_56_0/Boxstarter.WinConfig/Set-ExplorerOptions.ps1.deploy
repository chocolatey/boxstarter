function Set-ExplorerOptions {
<#
.SYNOPSIS
Sets options on the windows Explorer shell

.PARAMETER showHidenFilesFoldersDrives
If this switch is set, hidden files will be shown in windows explorer

.PARAMETER showProtectedOSFiles
If this flag is set, hidden Operating System files will be shown in windows explorer

.PARAMETER showFileExtensions
Setting this switch will cause windows explorer to include the file extension in file names

.LINK
http://boxstarter.codeplex.com

#>    
    param(
        [switch]$showHidenFilesFoldersDrives, 
        [switch]$showProtectedOSFiles, 
        [switch]$showFileExtensions
    )
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    if($showHidenFilesFoldersDrives) {Set-ItemProperty $key Hidden 1}
    if($showFileExtensions) {Set-ItemProperty $key HideFileExt 0}
    if($showProtectedOSFiles) {Set-ItemProperty $key ShowSuperHidden 1}
    Restart-Explorer
}
