function Add-VHDStartupScript {
    param(
        [string]$VHDPath,
        [string]$TargetScriptDirectory,
        [string[]]$FilesToCopy = @(),
        [ScriptBlock]$Script
    )    
    $volume=mount-vhd $VHDPath -Passthru | get-disk | Get-Partition | Get-Volume
    $winVolume = $volume | ? {Test-Path "$($_.DriveLetter):\windows"}
    mkdir "$($winVolume.DriveLetter):\$targetScriptDirectory"

    New-Item "$($winVolume.DriveLetter):\$targetScriptDirectory\startup.bat" -Type File -Value "powershell -ExecutionPolicy Bypass -NoProfile -File `"%SystemDrive%\$targetScriptDirectory\startup.ps1`""
    New-Item "$($winVolume.DriveLetter):\$targetScriptDirectory\startup.ps1" -Type File -Value $script.ToString()
    ForEach($file in $FilesToCopy){
        Copy-Item $file "$($winVolume.DriveLetter):\boxstarter"
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
