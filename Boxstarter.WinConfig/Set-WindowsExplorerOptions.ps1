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

.PARAMETER EnableExpandToOpenFolder
Setting this switch will cause Windows Explorer to expand the navigation pane to the current open folder

.PARAMETER DisableExpandToOpenFolder
Disables the expanding of the navigation page to the current open folder in Windows Explorer, see EnableExpandToOpenFolder

.PARAMETER EnableOpenFileExplorerToQuickAccess
Setting this switch will cause Windows Explorer to open itself to the Computer view, rather than the Quick Access view

.PARAMETER DisableOpenFileExplorerToQuickAccess
Disables the Quick Access location and shows Computer view when opening Windows Explorer, see EnableOpenFileExplorerToQuickAccess

.PARAMETER EnableShowRecentFilesInQuickAccess
Setting this switch will cause Windows Explorer to show recently used files in the Quick Access pane

.PARAMETER DisableShowRecentFilesInQuickAccess
Disables the showing of recently used files in the Quick Access pane, see EnableShowRecentFilesInQuickAccess

.PARAMETER EnableShowFrequentFoldersInQuickAccess
Setting this switch will cause Windows Explorer to show frequently used directories in the Quick Access pane

.PARAMETER DisableShowFrequentFoldersInQuickAccess
Disables the showing of frequently used directories in the Quick Access pane, see EnableShowFrequentFoldersInQuickAccess

.PARAMETER EnableShowRibbon
Setting this switch will cause Windows Explorer to show the Ribbon menu so that it is always expanded

.PARAMETER DisableShowRibbon
Disables the showing of the Ribbon menu in Windows Explorer so that it shows only the tab names, see EnableShowRibbon

.PARAMETER EnableSnapAssist
Enables Windows snap feature (side by side application selection tool). 

.PARAMETER DisableSnapAssist
Disables Windows snap feature (side by side application selection tool).

.LINK
https://boxstarter.org

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
        [switch]$DisableShowFullPathInTitleBar,
        [switch]$EnableExpandToOpenFolder,
        [switch]$DisableExpandToOpenFolder,
        [switch]$EnableOpenFileExplorerToQuickAccess,
        [switch]$DisableOpenFileExplorerToQuickAccess,
        [switch]$EnableShowRecentFilesInQuickAccess,
        [switch]$DisableShowRecentFilesInQuickAccess,
        [switch]$EnableShowFrequentFoldersInQuickAccess,
        [switch]$DisableShowFrequentFoldersInQuickAccess,
        [switch]$EnableShowRibbon,
        [switch]$DisableShowRibbon,
        [switch]$EnableSnapAssist,
        [switch]$DisableSnapAssist
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
    $ribbonKey = "$key\Ribbon"

    Write-BoxstarterMessage "Setting Windows Explorer options..."

    if(Test-Path -Path $key) {
        if($EnableShowRecentFilesInQuickAccess) {Set-ItemProperty $key ShowRecent 1}
        if($DisableShowRecentFilesInQuickAccess) {Set-ItemProperty $key ShowRecent 0}

        if($EnableShowFrequentFoldersInQuickAccess) {Set-ItemProperty $key ShowFrequent 1}
        if($DisableShowFrequentFoldersInQuickAccess) {Set-ItemProperty $key ShowFrequent 0}
    }

    if(Test-Path -Path $advancedKey) {
        if($EnableShowHiddenFilesFoldersDrives) {Set-ItemProperty $advancedKey Hidden 1}
        if($DisableShowHiddenFilesFoldersDrives) {Set-ItemProperty $advancedKey Hidden 0}

        if($EnableShowFileExtensions) {Set-ItemProperty $advancedKey HideFileExt 0}
        if($DisableShowFileExtensions) {Set-ItemProperty $advancedKey HideFileExt 1}

        if($EnableShowProtectedOSFiles) {Set-ItemProperty $advancedKey ShowSuperHidden 1}
        if($DisableShowProtectedOSFiles) {Set-ItemProperty $advancedKey ShowSuperHidden 0}

        if($EnableExpandToOpenFolder) {Set-ItemProperty $advancedKey NavPaneExpandToCurrentFolder 1}
        if($DisableExpandToOpenFolder) {Set-ItemProperty $advancedKey NavPaneExpandToCurrentFolder 0}

        if($EnableOpenFileExplorerToQuickAccess) {Set-ItemProperty $advancedKey LaunchTo 2}
        if($DisableOpenFileExplorerToQuickAccess) {Set-ItemProperty $advancedKey LaunchTo 1}

        if($EnableSnapAssist) {Set-ItemProperty $advancedKey SnapAssist 1}
        if($DisableSnapAssist) {Set-ItemProperty $advancedKey SnapAssist 0}
    }

    if(Test-Path -Path $cabinetStateKey) {
        if($EnableShowFullPathInTitleBar) {Set-ItemProperty $cabinetStateKey FullPath  1}
        if($DisableShowFullPathInTitleBar) {Set-ItemProperty $cabinetStateKey FullPath  0}
    }

    if(Test-Path -Path $ribbonKey) {
        if($EnableShowRibbon) {Set-ItemProperty $ribbonKey MinimizedStateTabletModeOff 0}
        if($DisableShowRibbon) {Set-ItemProperty $ribbonKey MinimizedStateTabletModeOff 1}
    }

    Restart-Explorer
}
