$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe "Add-VHDStartupScript" {
    try{
        $TargetScriptDirectory = "Boxstarter.Startup"
        Import-Module "$here\..\..\Boxstarter.VirtualMachine\Boxstarter.VirtualMachine.psd1" -Force
        $testRoot=(Get-PSDrive TestDrive).Root

        Context "When adding a startup script to a clean vhd" {
            $v = new-vhd -Path $testRoot\test.vhdx -SizeBytes 200MB | Mount-VHD -PassThru | Initialize-Disk -PartitionStyle mbr -Confirm:$false -PassThru | New-Partition -UseMaximumSize -AssignDriveLetter -MbrType IFS | Format-Volume -Confirm:$false
            Get-PSDrive | Out-Null
            mkdir "$($v.DriveLetter):\Windows\System32\config" | Out-Null
            reg save HKLM\Software "$($v.DriveLetter):\Windows\System32\config\SOFTWARE" /y /c | Out-Null
            Dismount-VHD $testRoot\test.vhdx
            New-Item "TestDrive:\file1.ps1" -Type File | Out-Null
            New-Item "TestDrive:\file2.ps1" -Type File | Out-Null

            Add-VHDStartupScript $testRoot\test.vhdx "$testRoot\file1.ps1","$testRoot\file2.ps1" {
                    function say-hi {"hi"}
                    say-hi
                } | Out-Null

            $vol = Mount-VHD "$testRoot\test.vhdx" -Passthru | get-disk | Get-Partition | Get-Volume
            It "Should create startup script"{
                & "$($vol.DriveLetter):\$TargetScriptDirectory\startup.bat" | should be "hi"
            }
            It "Should copy supporting scripts"{
                Test-Path "$($vol.DriveLetter):\$TargetScriptDirectory\file1.ps1" | should be $true
                Test-Path "$($vol.DriveLetter):\$TargetScriptDirectory\file2.ps1" | should be $true
            }
            It "Should set Group Policy"{
                reg load HKLM\VHDSYS "$($vol.DriveLetter):\windows\system32\config\software" | Out-Null
                (Get-ItemProperty -path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\0" -name Script).Script | should be "%SystemDrive%\$TargetScriptDirectory\startup.bat"
            }
            reg unload HKLM\VHDSYS | Out-Null
            Dismount-VHD $testRoot\test.vhdx
        }

        Context "When providing a nonexistent vhd path" {

            try {
                Add-VHDStartupScript $testRoot\notest.vhdx "$testRoot\file1.ps1","$testRoot\file2.ps1" {
                    function say-hi {"hi"}
                    say-hi
                } | Out-Null
            }
            catch{
                $err = $_
            }

            It "Should throw a validation error"{
                $err.CategoryInfo.Category | should be "InvalidData"
            }
        }

        Context "When providing a path to a non vhd" {

            try {
                Add-VHDStartupScript $env:SystemRoot "$testRoot\file1.ps1","$testRoot\file2.ps1" {
                    function say-hi {"hi"}
                    say-hi
                } | Out-Null
            }
            catch{
                $err = $_
            }

            It "Should throw a validation error"{
                $err.CategoryInfo.Category | should be "InvalidData"
            }
        }

        Context "When the vhd is read only" {
            $v = new-vhd -Path $testRoot\test.vhdx -SizeBytes 200MB | Mount-VHD -PassThru | Initialize-Disk -PartitionStyle mbr -PassThru | New-Partition -UseMaximumSize -AssignDriveLetter -MbrType IFS | Format-Volume -Confirm:$false
            Get-PSDrive | Out-Null
            mkdir "$($v.DriveLetter):\Windows\System32\config" | Out-Null
            reg save HKLM\Software "$($v.DriveLetter):\Windows\System32\config\SOFTWARE" /y /c | Out-Null
            Dismount-VHD $testRoot\test.vhdx
            Set-ItemProperty $testRoot\test.vhdx -name IsReadOnly -Value $true

            try {
                Add-VHDStartupScript $testRoot\test.vhdx "$testRoot\file1.ps1","$testRoot\file2.ps1" {
                    function say-hi {"hi"}
                    say-hi
                } | Out-Null
            }
            catch{
                $err = $_
            }

            It "Should throw a InvalidOperation Exception"{
                $err.CategoryInfo.Reason | should be "InvalidOperationException"
            }
        }

    }
    finally{
        reg unload HKLM\VHDSYS 2>&1 | Out-Null
        if(Test-Path $testRoot\test.vhdx){
            Dismount-VHD $testRoot\test.vhdx -ErrorAction SilentlyContinue
            Remove-Item $testRoot\test.vhdx
        }
    }
}