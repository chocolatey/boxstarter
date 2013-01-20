function Disable-InternetExplorerESC {
<#
.SYNOPSIS
Turns off IE Enhansed Security Configuration that is on by defaulton Server OS versions

.LINK
http://boxstarter.codeplex.com

#>
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    if(Test-Path $AdminKey){
        Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
        $disabled = $true
    }
    if(Test-Path $UserKey) {
        Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
        $disabled = $true
    }
    if($disabled) {
        Restart-Explorer
        Write-Output "IE Enhanced Security Configuration (ESC) has been disabled."
    }
}
