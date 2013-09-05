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

.PARAMETER FilesToCopy
A array of paths that will be copied to the 'Boxstarter.Startup'
directory in the root of the VHD.

.PARAMETER Script
ScriptBlock to invoke when the VHD boots

.EXAMPLE
$vhd=Get-VMHardDiskDrive -VMName MyVM
$fileToCopy="c:\path\EnablePsRemotingOnServer.ps1"
Add-VHDStartupScript $vhd.Path $fileToCopy {
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
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateScript({(Test-Path $_) -and ($_ -like "*.vhd" -or $_ -like "*.vhdx" -or $_ -like "*.avhdx")})]
        [string]$VHDPath,
        [Parameter(Position=1,Mandatory=$true)]
        [ScriptBlock]$Script,
        [Parameter(Position=2,Mandatory=$false)]
        [ValidateScript({ $_ | % {Test-Path $_} })]
        [string[]]$FilesToCopy = @()
    )
    if((Get-ItemProperty $VHDPath -Name IsReadOnly).IsReadOnly){
        throw New-Object -TypeName InvalidOperationException -ArgumentList "The VHD is Read-Only"
    }    
    $volume=mount-vhd $VHDPath -Passthru | get-disk | Get-Partition | Get-Volume
    try{
        $winVolume = $volume | ? {Test-Path "$($_.DriveLetter):\windows"}
        if($winVolume -eq $null){
            throw New-Object -TypeName InvalidOperationException -ArgumentList "The VHD does not contain system volume"
        }    

        $TargetScriptDirectory = "Boxstarter.Startup"
        mkdir "$($winVolume.DriveLetter):\$targetScriptDirectory" -Force | out-null
        New-Item "$($winVolume.DriveLetter):\$targetScriptDirectory\startup.bat" -Type File -Value "@echo off`r`npowershell -ExecutionPolicy Bypass -NoProfile -File `"%~dp0startup.ps1`"" -force | out-null
        New-Item "$($winVolume.DriveLetter):\$targetScriptDirectory\startup.ps1" -Type File -Value $script.ToString() -force | out-null
        ForEach($file in $FilesToCopy){
            Copy-Item $file "$($winVolume.DriveLetter):\$targetScriptDirectory" -Force
        }

        reg load HKLM\VHDSYS "$($winVolume.DriveLetter):\windows\system32\config\software" | out-null
        $startupRegFile = Get-RegFile
        reg import $startupRegFile 2>&1 | out-null
        [GC]::Collect() # The next line will fail without this since handles to the loaded hive have not yet been collected
        reg unload HKLM\VHDSYS | out-null
        Remove-Item $startupRegFile -force
    }
    finally{
        Dismount-VHD $VHDPath
    }
}

function Get-RegFile {
    $regFileTemplate = "$($boxstarter.BaseDir)\boxstarter.VirtualMachine\startupScript.reg"
    $startupRegFile = "$env:Temp\startupScript.reg"
    if(Test-Path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\0"){
        $localGPO = Get-ChildItem "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup" | ? {
            (Get-ItemProperty -path $_.PSPath -Name DisplayName).DisplayName -eq "Local Group Policy"
        }
        if($localGPO -ne $null) {
            $localGPONum = $localGPO.PSChildName
            $localGPO=$null #free the key for GC so it can be unloaded
        }
        else{
            $localGPONum = "0"
            Shift-OtherGPOs "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup"
            Shift-OtherGPOs "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup"
        }
        $scriptDirs = Get-ChildItem "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\$localGPONum"
        $existingScriptDir = $scriptDirs | ? { 
            (Get-ItemProperty -path $_.PSPath -Name Script).Script -like "*\Boxstarter.Startup\startup.bat"
        }
        if($existingScriptDir -eq $null){
            [int]$scriptNum = $scriptDirs[-1].PSChildName
            $scriptNum += 1
        }
        else {
            [int]$scriptNum = $existingScriptDir.PSChildName
            $existingScriptDir = $null #free the key for GC so it can be unloaded
        }
        (Get-Content $regFileTemplate) | % {
            $_ -Replace "\\0\\0", "\$localGPONum\$scriptNum"
        } | Set-Content $startupRegFile -force
        $scriptDirs=$null
    }
    else{
        Copy-Item $regFileTemplate $env:Temp
    }
    return $startupRegFile
}

function Shift-OtherGPOs($parentPath){
    Get-ChildItem $parentPath | Sort-Object -Descending | % {
        [int]$num = $_.PSChildName
        $oldName = $_.Name.Replace("HKEY_LOCAL_MACHINE","HKLM:")
        [string]$newName = "$($num+1)"
        try {Rename-Item -Path $oldName -NewName $newName} catch [System.InvalidCastException] {}
    }
}