function Remove-VhdStartupScript {
<#
.SYNOPSIS
Removes a Srtartup Script from a VHD adding that had been previously 
added by Add-VHDStartupScript.

.DESCRIPTION
This cmdlet cleans up the script, files and group policy originally 
created by Add-VHDStartupScript.

.PARAMETER VHDPath
The path where the VHD exists.

.EXAMPLE
$vhd=Get-VMHardDiskDrive -VMName MyVM
Remove-VHDStartupScript $vhd.Path 

Removes any previous startup script and startup script artifacts
let behind by Add-VHDStartupScript

.LINK
http://boxstarter.codeplex.com
Add-VHDStartupScript
#>
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateScript({Test-Path $_})]
        [ValidatePattern("\.(a)?vhd(x)?$")]
        [string]$VHDPath
    )
    Write-BoxstarterMessage "Removing startup script from $VHDPath"
    if((Get-ItemProperty $VHDPath -Name IsReadOnly).IsReadOnly){
        throw New-Object -TypeName InvalidOperationException -ArgumentList "The VHD is Read-Only"
    }    
    $volume=mount-vhd $VHDPath -Passthru | get-disk | Get-Partition | Get-Volume
    try{
        Get-PSDrive | Out-Null
        $winVolume = $volume | ? {Test-Path "$($_.DriveLetter):\windows\System32\config"}
        if($winVolume -eq $null){
            throw New-Object -TypeName InvalidOperationException -ArgumentList "The VHD does not contain system volume"
        }    
        Write-BoxstarterMessage "Mounted VHD with system volume to Drive $($winVolume.DriveLetter)"
        $TargetScriptDirectory = "Boxstarter.Startup"
        if(Test-Path "$($winVolume.DriveLetter):\$targetScriptDirectory") {
            Write-BoxstarterMessage "Removing $TargetScriptDirectory directory"
            try { 
                Remove-Item "$($winVolume.DriveLetter):\$targetScriptDirectory" -Recurse -Force -ErrorAction Ignore
            } catch{}
        }
        Write-BoxstarterMessage "Loading VHD HKLM\Software hive to HKLM\VHDSYS"
        reg load HKLM\VHDSYS "$($winVolume.DriveLetter):\windows\system32\config\software" | out-null
        $policyKey = "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy"
        Remove-StartupScriptPolicy "$policyKey\Scripts"
        Remove-StartupScriptPolicy "$policyKey\State\Machine\Scripts"
    }
    finally{
        [GC]::Collect() # The next line will fail without this since handles to the loaded hive have not yet been collected
        reg unload HKLM\VHDSYS 2>&1 | out-null
        Write-BoxstarterMessage "VHD Registry Unloaded"
        Dismount-VHD $VHDPath
        Write-BoxstarterMessage "VHD Dismounted"
    }
}

function Remove-StartupScriptPolicy($regKey) {
    #Find Script Node
    #Delete it

    #DoesParent Have Items?
    #No? - Delete it

    #Does Grandparent have Items?
    #No? - Delete startup node
    #Yes? - Shift Them Up

    #Are there shutdown scripts?
    #No? Delete Scripts node
    Remove-Item $regKey -Recurse -Force
}