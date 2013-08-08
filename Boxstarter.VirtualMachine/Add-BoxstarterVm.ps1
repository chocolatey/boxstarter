function Add-BoxstarterVm {
    param($vhdPath)
    $vhdFile = Get-Item c:\dev\vmt\win7\win7.vhdx
    Copy-Item "C:\Users\Public\Documents\Hyper-V\Virtual hard disks\win7.vhdx" $vhdFile.FullName -force
    $vhdFile.IsReadOnly=$false
    $switch=Get-VMSwitch | ?{$_.SwitchType -eq "Internal"}
    new-vm win7New -MemoryStartupBytes 2147483648 -SwitchName $switch[0].Name -VHDPath c:\dev\vmt\win7\win7.vhdx -Path c:\dev\vmt\win7
}