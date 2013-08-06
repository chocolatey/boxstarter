function Set-TaskbarSmall {
<#
.SYNOPSIS
Makes the windows task bar skinny
#>
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-ItemProperty $key TaskbarSmallIcons 1
    Restart-Explorer
}
