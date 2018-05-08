function Enable-UAC {
<#
.SYNOPSIS
Turns on Windows User Access Control

.LINK
https://boxstarter.org

#>
    Write-BoxstarterMessage "Enabling UAC"
    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name EnableLUA  -Value 1
}
