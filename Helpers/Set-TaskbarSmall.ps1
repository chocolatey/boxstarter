function Set-TaskbarSmall {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-ItemProperty $key TaskbarSmallIcons 1
    Restart-Explorer
}
