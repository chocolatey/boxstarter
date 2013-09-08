$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\common.ps1"

Describe "Get-VHDComputerName" {
    try{
        Import-Module "$here\..\..\Boxstarter.VirtualMachine\Boxstarter.VirtualMachine.psd1" -Force
        $Boxstarter.SuppressLogging=$true
        mkdir $env:temp\Boxstarter.tests | Out-Null
        $testRoot="$env:temp\Boxstarter.tests"
        $v = new-vhd -Path $testRoot\test.vhdx -SizeBytes 50MB | Mount-VHD -PassThru | Initialize-Disk -PartitionStyle mbr -Confirm:$false -PassThru | New-Partition -UseMaximumSize -AssignDriveLetter -MbrType IFS | Format-Volume -NewFileSystemLabel "VHD" -Confirm:$false
        Get-PSDrive | Out-Null
        mkdir "$($v.DriveLetter):\Windows\System32\config" | Out-Null
        reg save HKLM\SYSTEM "$($v.DriveLetter):\Windows\System32\config\SYSTEM" /y /c | Out-Null
        Dismount-VHD $testRoot\test.vhdx

        Context "When mirroring this computer's registry" {

            $computerName = Get-VHDComputerName $testRoot\test.vhdx

            It "Should return the same Computername"{
                $computerName | should be $env:Computername
            }
        }

        Context "When providing a nonexistent vhd path" {

            try {
                Get-VHDComputerName $testRoot
            }
            catch{
                $err = $_
            }

            It "Should throw a validation error"{
                $err.CategoryInfo.Category | should be "InvalidData"
            }
        }

        Context "When providing a path to a non vhd" {
            New-Item $testRoot\test.vhdxb -type File | Out-Null

            try {
                Get-VHDComputerName $testRoot\test.vhdxb
            }
            catch{
                $err = $_
            }

            It "Should throw a validation error"{
                $err.CategoryInfo.Category | should be "InvalidData"
            }
        }

        Context "When the vhd is not a system volume" {
            $v = Mount-TestVHD -DoNotLoadRegistry
            Remove-Item "$($v.DriveLetter):\Windows\System32\config" -recurse -Force
            Dismount-VHD $testRoot\test.vhdx

            try {
                Get-VHDComputerName $testRoot\test.vhdx            }
            catch{
                $err = $_
            }
            finally{
                $v = Mount-TestVHD -DoNotLoadRegistry
                mkdir "$($v.DriveLetter):\Windows\System32\config" | Out-Null
                reg save HKLM\SYSTEM "$($v.DriveLetter):\Windows\System32\config\SYSTEM" /y /c | Out-Null
            }

            It "Should throw a InvalidOperation Exception"{
                $err.CategoryInfo.Reason | should be "InvalidOperationException"
            }
        }        
    }
    finally{
        [GC]::Collect()
        reg unload HKLM\VHDSYS 2>&1 | Out-Null
        if(Test-Path $testRoot\test.vhdx){
            Dismount-VHD $testRoot\test.vhdx -ErrorAction SilentlyContinue
            Remove-Item $testRoot\test.vhdx
        }
        del $env:temp\Boxstarter.tests -recurse -force
    }
}