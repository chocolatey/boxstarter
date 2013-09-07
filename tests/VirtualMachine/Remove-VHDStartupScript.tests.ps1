$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\common.ps1"

Describe "Remove-VHDStartupScript" {
    try{
        $TargetScriptDirectory = "Boxstarter.Startup"
        Import-Module "$here\..\..\Boxstarter.VirtualMachine\Boxstarter.VirtualMachine.psd1" -Force
        $Boxstarter.SuppressLogging=$true
        mkdir $env:temp\Boxstarter.tests | Out-Null
        $testRoot="$env:temp\Boxstarter.tests"
        $v = new-vhd -Path $testRoot\test.vhdx -SizeBytes 200MB | Mount-VHD -PassThru | Initialize-Disk -PartitionStyle mbr -Confirm:$false -PassThru | New-Partition -UseMaximumSize -AssignDriveLetter -MbrType IFS | Format-Volume -NewFileSystemLabel "VHD" -Confirm:$false
        Get-PSDrive | Out-Null
        mkdir "$($v.DriveLetter):\Windows\System32\config" | Out-Null
        reg save HKLM\Software "$($v.DriveLetter):\Windows\System32\config\SOFTWARE" /y /c | Out-Null
        Dismount-VHD $testRoot\test.vhdx
        New-Item "$testRoot\file1.ps1" -Type File | Out-Null
        New-Item "$testRoot\file2.ps1" -Type File | Out-Null

        Context "When Removing a startup script from a vhd with a single script" {
            Add-VHDStartupScript $testRoot\test.vhdx -FilesToCopy "$testRoot\file1.ps1","$testRoot\file2.ps1" {
                    function say-hi {"hi"}
                    say-hi
                }

            Remove-VHDStartupScript $testRoot\test.vhdx

            $vol = Mount-TestVHD
            It "Should remove startup script directory"{
                Test-Path "$($vol.DriveLetter):\$TargetScriptDirectory" | should be $False
            }
            It "Should Remove Group Policy Scripts"{
                test-path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\Scripts" | should be $false
            }
            It "Should Remove Group Policy State Scripts"{
                test-path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts" | should be $false
            }            
            Clean-VHD
        }

        Context "When there is no startup script" {
            $out = Remove-VHDStartupScript $testRoot\test.vhdx 2>&1 | out-string

            It "Should not throw an error"{
                $out | should be ""
            }
        }

        Context "When providing a nonexistent vhd path" {

            try {
                Remove-VHDStartupScript $testRoot\notest.vhdx
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
                Remove-VHDStartupScript $env:SystemRoot
            }
            catch{
                $err = $_
            }

            It "Should throw a validation error"{
                $err.CategoryInfo.Category | should be "InvalidData"
            }
        }

        Context "When the vhd is read only" {
            Set-ItemProperty $testRoot\test.vhdx -name IsReadOnly -Value $true

            try {
                Remove-VHDStartupScript $testRoot\test.vhdx
            }
            catch{
                $err = $_
            }
            finally{
                Set-ItemProperty $testRoot\test.vhdx -name IsReadOnly -Value $false
            }

            It "Should throw a InvalidOperation Exception"{
                $err.CategoryInfo.Reason | should be "InvalidOperationException"
            }
        }

        Context "When the vhd is not a system volume" {
            $v = Mount-TestVHD -DoNotLoadRegistry
            Remove-Item "$($v.DriveLetter):\Windows\System32\config" -recurse -Force
            Dismount-VHD $testRoot\test.vhdx

            try {
                Remove-VHDStartupScript $testRoot\test.vhdx
            }
            catch{
                $err = $_
            }
            finally{
                $v = Mount-TestVHD -DoNotLoadRegistry
                mkdir "$($v.DriveLetter):\Windows\System32\config" | Out-Null
                reg save HKLM\Software "$($v.DriveLetter):\Windows\System32\config\SOFTWARE" /y /c | Out-Null
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