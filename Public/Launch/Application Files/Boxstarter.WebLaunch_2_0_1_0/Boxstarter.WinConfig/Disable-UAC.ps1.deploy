<#A Build step copies this function to bootstrapper Directory. Only edit script in Helpers#>
function Disable-UAC {
<#
.SYNOPSIS
Turns off Windows User Access Control

.LINK
http://boxstarter.codeplex.com
Enable-UAC

#>
    Write-BoxstarterMessage "Disabling UAC"
    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name EnableLUA  -Value 0
}
