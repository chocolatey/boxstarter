<#A Build step copies this function to bootstrapper Directory. Only edit script in Helpers#>
function Enable-UAC {
<#
.SYNOPSIS
Turns on Windows User Access Control

.LINK
http://boxstarter.codeplex.com

#>
    Write-BoxstarterMessage "Enabling UAC"
    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name EnableLUA  -Value 1
}
