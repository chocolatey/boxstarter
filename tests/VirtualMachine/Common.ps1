function Mount-TestVHD ([switch]$DoNotLoadRegistry){
    $v = Mount-VHD $testRoot\test.vhdx -Passthru | get-disk | Get-Partition | Get-Volume
    Get-PSDrive | Out-Null
    if(!$DoNotLoadRegistry){
        reg load HKLM\VHDSYS "$($v.DriveLetter):\windows\system32\config\software" | Out-Null
    }
    return $v
}

function Clean-VHD {
    [GC]::Collect()
    $vol = Get-Volume | ? {$_.FileSystemLabel -eq "VHD"}
    reg unload HKLM\VHDSYS | Out-Null
    Remove-Item "$($vol.DriveLetter):\Windows\System32\config\SOFTWARE"
    reg save HKLM\Software "$($vol.DriveLetter):\Windows\System32\config\SOFTWARE" /y /c | Out-Null
    Dismount-VHD $testRoot\test.vhdx
}