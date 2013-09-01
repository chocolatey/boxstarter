$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe "Add-VHDStartupScript" {
    try{
        $testRoot=(Get-PSDrive TestDrive).Root
        Import-Module "$here\..\..\Boxstarter.VirtualMachine\Boxstarter.VirtualMachine.psd1" -Force
        $testRoot=(Get-PSDrive TestDrive).Root
        $v = new-vhd -Path $testRoot\test.vhdx -SizeBytes 200MB | Mount-VHD -PassThru | Initialize-Disk -PartitionStyle mbr -PassThru | New-Partition -UseMaximumSize -AssignDriveLetter -MbrType IFS | Format-Volume -Confirm:$false
        Get-PSDrive | Out-Null
        mkdir "$($v.DriveLetter):\Windows\System32\config" | Out-Null
        reg save HKLM\Software "$($v.DriveLetter):\Windows\System32\config\SOFTWARE" /y /c | Out-Null
        Dismount-VHD $testRoot\test.vhdx
        New-Item "TestDrive:\file1.ps1" -Type File | Out-Null
        New-Item "TestDrive:\file2.ps1" -Type File | Out-Null

        Context "When adding a startup script to a clean vhd" {

            Add-VHDStartupScript $testRoot\test.vhdx "StartupDir" "$testRoot\file1.ps1","$testRoot\file2.ps1" {
                    function say-hi {"hi"}
                    say-hi
                } | Out-Null

            $vol = Mount-VHD "$testRoot\test.vhdx" -Passthru | get-disk | Get-Partition | Get-Volume
            It "Should create startup script"{
                & "$($vol.DriveLetter):\StartupDir\startup.bat" | should be "hi"
            }
            It "Should copy supporting scripts"{
                Test-Path "$($vol.DriveLetter):\StartupDir\file1.ps1" | should be $true
                Test-Path "$($vol.DriveLetter):\StartupDir\file2.ps1" | should be $true
            }
            It "Should set Group Policy"{
                reg load HKLM\VHDSYS "$($vol.DriveLetter):\windows\system32\config\software" | Out-Null
                (Get-ItemProperty -path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\0" -name Script).Script | should be "%SystemDrive%\StartupDir\startup.bat"
            }
            reg unload HKLM\VHDSYS | Out-Null
            Dismount-VHD $testRoot\test.vhdx
            Remove-Item $testRoot\test.vhdx
        }
    }
    finally{
        if(Test-Path $testRoot\test.vhdx){
            Dismount-VHD $testRoot\test.vhdx
            Remove-Item $testRoot\test.vhdx
        }
    }
}