function Disable-UAC {
<#
.SYNOPSIS
Turns off Windows User Access Control

.LINK
https://boxstarter.org
Enable-UAC

#>
    Write-BoxstarterMessage "Disabling UAC"
    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name EnableLUA  -Value 0
}
