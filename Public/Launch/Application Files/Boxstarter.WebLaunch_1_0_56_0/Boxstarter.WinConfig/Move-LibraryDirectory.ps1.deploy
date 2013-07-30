function Move-LibraryDirectory {
<#
.SYNOPSIS
Moves a Windows Library folder (My Pictures, personal, downloads, etc) to the given path

.DESCRIPTION
Libraries are special folders that map to a specific location on disk. These are usually found somewhere under $env:userprofile. This function can be used to redirect the library folder to a new location on disk. If the new location does not already exist, the directory will be created. Any content in the former library directory will be moved to the new location unless the DoNotMoveOldContent switch is used. Use Get-LibraryNames to discover the names of different libraries and their current physical directories.

.PARAMETER libraryName
The name of the library to move

.PARAMETER newPath
The path to move the library to. If the path does not exist, it will be created.

.PARAMETER DoNotMoveOldContent
If this switch is used, any content in the current physical directory that the library points to will not be moved to the new path.

.EXAMPLE
Move-LibraryDirectory "Personal" "$env:UserProfile\skydrive\documents"

This moves the Personal library (aka Documents) to the documents folder off of the default skydrive directory.

.LINK
http://boxstarter.codeplex.com
Get-LibraryNames

#>    
    param(
        [Parameter(Mandatory=$true)]
        [string]$libraryName, 
        [Parameter(Mandatory=$true)]
        [string]$newPath,
        [switch]$DoNotMoveOldContent
    )
    #why name the key downloads when you can name it {374DE290-123F-4565-9164-39C4925E467B}? duh.
    if($libraryName.ToLower() -eq "downloads") {$libraryName="{374DE290-123F-4565-9164-39C4925E467B}"}
    $shells = (Get-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders')
    if(-not ($shells.Property -Contains $libraryName)) {
        throw "$libraryName is not a valid Library"
    }
    $oldPath =  (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -name "$libraryName")."$libraryName"
    if(-not (test-path "$newPath")){
        New-Item $newPath -type directory
    }
    if((resolve-path $oldPath).Path -eq (resolve-path $newPath).Path) {return}
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' $libraryName $newPath
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' $libraryName $newPath
    Restart-Explorer
    if(!$DoNotMoveOldContent) { Move-Item -Force $oldPath/* $newPath }
}
