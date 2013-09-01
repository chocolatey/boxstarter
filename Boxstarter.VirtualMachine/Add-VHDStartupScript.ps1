function Add-VHDStartupScript {
<#
.SYNOPSIS
Modifies a VHD adding a script that will be exeuted when the VHD's 
VM boots

.DESCRIPTION
Add-VHDStartupScript adds a script block to be invoked when a guest
VM boots with the VHD passed to Add-VHDStartupScript. The VHD must
contain the SystemDrive used by the VM. The registry stored on the 
VHD is modified to create a Group Policy startup script 
configuration. The script will be run under the Local System account
identity with administrative privileges.

.PARAMETER VHDPath
The path where the VHD exists.

.PARAMETER TargetScriptDirectory
The name of the directory that will be created at the root of the 
SystemDrive where the script will be saved as Startup.ps1 and all
paths in FilesToCopy will be saved.

.PARAMETER FilesToCopy
A array of paths that will be copied to TargetScriptDirectory

.PARAMETER Script
ScriptBlock to invoke when the VHD boots

.EXAMPLE
$vhd=Get-VMHardDiskDrive -VMName MyVM
$fileToCopy="c:\path\EnablePsRemotingOnServer.ps1"
Add-VHDStartupScript $vhd.Path "MyStartupDir" $fileToCopy {
    netsh advfirewall firewall set rule name="File and Printer Sharing (SMB-In)" new enable=yes profile=any
    reg add HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\system /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f
}

This adds a script to the VHD beloning to a VM named MyVM.
The script enables inbound SMB traffic and enables the 
LocalAccountTokenFilterPolicy. It also copies the 
EnablePsRemotingOnServer.ps1 file onto the VHD.

This would allow one to use PSEXEC on the VM to run the
EnablePsRemotingOnServer.ps1 script that may contain
Enable-PSRemoting -Force and thereby enable PSRemoting
on the VM.

.LINK
http://boxstarter.codeplex.com
#>
    [CmdletBinding()]
    param(
        [string]$VHDPath,
        [string]$TargetScriptDirectory,
        [string[]]$FilesToCopy = @(),
        [ScriptBlock]$Script
    )    
    $volume=mount-vhd $VHDPath -Passthru | get-disk | Get-Partition | Get-Volume
    $winVolume = $volume | ? {Test-Path "$($_.DriveLetter):\windows"}
    mkdir "$($winVolume.DriveLetter):\$targetScriptDirectory"

    New-Item "$($winVolume.DriveLetter):\$targetScriptDirectory\startup.bat" -Type File -Value "@echo off`r`npowershell -ExecutionPolicy Bypass -NoProfile -File `"%~dp0startup.ps1`""
    New-Item "$($winVolume.DriveLetter):\$targetScriptDirectory\startup.ps1" -Type File -Value $script.ToString()
    ForEach($file in $FilesToCopy){
        Copy-Item $file "$($winVolume.DriveLetter):\$targetScriptDirectory"
    }
    $startupRegFile = "$env:Temp\startupScript.reg"
    Get-Content "$($boxstarter.BaseDir)\boxstarter.VirtualMachine\startupScript.reg" | % {
        $_ -Replace "%startupDir%", $TargetScriptDirectory
    } | Set-Content $startupRegFile
    reg load HKLM\VHDSYS "$($winVolume.DriveLetter):\windows\system32\config\software"
    reg import $startupRegFile
    reg unload HKLM\VHDSYS
    Dismount-VHD $VHDPath
}
