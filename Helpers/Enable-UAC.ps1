function Enable-UAC {
<#
.SYNOPSIS
Turns on Windows User Access Control

.LINK
http://boxstarter.codeplex.com

#>
    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name EnableLUA  -Value 1
}
