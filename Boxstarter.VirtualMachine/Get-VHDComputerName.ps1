function Get-VHDComputerName {
<#
.SYNOPSIS
Gets the Computer Name that a system volume VHD is attached to

.DESCRIPTION
This cmdlet retrieves the Computer Name from the Registry 
values stored in the VHD. The VHD must contain the system
volume that houses the windows registry.

.PARAMETER VHDPath
The path where the VHD exists.

.EXAMPLE
$vhd=Get-VMHardDiskDrive -VMName MyVM
$computerName=Get-VHDComputerName $vhd.Path

.LINK
http://boxstarter.codeplex.com
#>
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateScript({Test-Path $_})]
        [ValidatePattern("\.(a)?vhd(x)?$")]
        [string]$VHDPath
    )
    $volume=mount-vhd $VHDPath -Passthru | get-disk | Get-Partition | Get-Volume
    try{
        Get-PSDrive | Out-Null
        $winVolume = $volume | ? {Test-Path "$($_.DriveLetter):\windows\System32\config"}
        if($winVolume -eq $null){
            throw New-Object -TypeName InvalidOperationException -ArgumentList "The VHD does not contain system volume"
        }    
        reg load HKLM\VHDSYS "$($winVolume.DriveLetter):\windows\system32\config\system" | out-null
        $current=(Get-ItemProperty "HKLM:\VHDSYS\Select" -Name Current).Current
        $computerName = (Get-ItemProperty "HKLM:\VHDSYS\ControlSet00$current\Control\ComputerName\ComputerName" -Name ComputerName).ComputerName
        return $computerName
    }
    finally{
        [GC]::Collect() # The next line will fail without this since handles to the loaded hive have not yet been collected
        reg unload HKLM\VHDSYS 2>&1 | out-null
        Dismount-VHD $VHDPath
    }
}