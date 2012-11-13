function Move-LibraryDirectory ([string]$libraryName, [string]$newPath) {
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
    Move-Item -Force $oldPath/* $newPath
}
