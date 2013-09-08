$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\common.ps1"

Describe "Remove-VHDStartupScript" {
    try{
        $policyKey = "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy"
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
                test-path "$policyKey\Scripts" | should be $false
            }
            It "Should Remove Group Policy State Scripts"{
                test-path "$policyKey\State\Machine\Scripts" | should be $false
            }
            Clean-VHD
        }

        Context "When Removing a startup script from a vhd with two local scripts" {
            Add-VHDStartupScript $testRoot\test.vhdx {
                function say-hi {"hi"}
                say-hi
            }
            $v = Mount-TestVHD
            Set-ItemProperty -path "$policyKey\Scripts\Startup\0\0" -name Script -value "%SystemDrive%\$TargetScriptDirectory\otherstartup.bat"
            Set-ItemProperty -path "$policyKey\State\Machine\Scripts\Startup\0\0" -name Script -value "%SystemDrive%\$TargetScriptDirectory\otherstartup.bat"
            [GC]::Collect()
            reg unload HKLM\VHDSYS | out-null
            Dismount-VHD $testRoot\test.vhdx
            Add-VHDStartupScript $testRoot\test.vhdx {
                function say-hi {"hi"}
                say-hi
            }

            Remove-VHDStartupScript $testRoot\test.vhdx

            $vol = Mount-TestVHD
            It "Should Remove 2nd Group Policy Scripts"{
                test-path "$policyKey\Scripts\Startup\0\1" | should be $false
            }
            It "Should Remove 2nd Group Policy State Scripts"{
                test-path "$policyKey\State\Machine\Scripts\Startup\0\1" | should be $false
            }            
            It "Should keep 1st Group Policy Scripts"{
                test-path "$policyKey\Scripts\Startup\0\0" | should be $true
            }
            It "Should keep 1st Group Policy State Scripts"{
                test-path "$policyKey\State\Machine\Scripts\Startup\0\0" | should be $true
            }
            Clean-VHD
        }

        Context "When Removing a startup script from a vhd with a local script and Domain Script" {
            Add-VHDStartupScript $testRoot\test.vhdx {
                function say-hi {"hi"}
                say-hi
            }
            $v = Mount-TestVHD
            Set-ItemProperty -path "$policyKey\Scripts\Startup\0" -name DisplayName -value "Domain Policy"
            Set-ItemProperty -path "$policyKey\State\Machine\Scripts\Startup\0" -name DisplayName -value "Domain Policy"
            [GC]::Collect()
            reg unload HKLM\VHDSYS | out-null
            Dismount-VHD $testRoot\test.vhdx
            Add-VHDStartupScript $testRoot\test.vhdx {
                function say-hi {"hi"}
                say-hi
            }

            Remove-VHDStartupScript $testRoot\test.vhdx

            $vol = Mount-TestVHD
            It "Should move Domain Group Policy to position 0"{
                (Get-ItemProperty -path "$policyKey\Scripts\Startup\0" -name DisplayName).DisplayName | should be "Domain Policy"
            }
            It "Should move state Domain Group Policy State Script to position 0"{
                (Get-ItemProperty -path "$policyKey\State\Machine\Scripts\Startup\0" -name DisplayName).DisplayName | should be "Domain Policy"
            }            
            It "Should Remove Local Group Policy Scripts"{
                test-path "$policyKey\Scripts\Startup\1\0" | should be $false
            }
            It "Should Remove Local Group Policy State Scripts"{
                test-path "$policyKey\State\Machine\Scripts\Startup\1\0" | should be $false
            }
            Clean-VHD
        }

        Context "When Removing a startup script from a vhd with a single script and shutdown script" {
            Add-VHDStartupScript $testRoot\test.vhdx {
                function say-hi {"hi"}
                say-hi
            }
            $v = Mount-TestVHD
            New-Item "$policyKey\Scripts\Shutdown\0" | Out-Null
            New-Item "$policyKey\State\Machine\Scripts\Shutdown\0" | Out-Null
            [GC]::Collect()
            reg unload HKLM\VHDSYS | out-null
            Dismount-VHD $testRoot\test.vhdx

            Remove-VHDStartupScript $testRoot\test.vhdx

            $vol = Mount-TestVHD
            It "Should Remove Startup Scripts"{
                (Get-ChildItem "$policyKey\Scripts\Startup").Count | should be 0
            }
            It "Should Remove Startup State Scripts"{
                (Get-ChildItem "$policyKey\State\Machine\Scripts\Startup").Count | should be 0
            }
            It "Should keep shutdown Scripts"{
                (Get-ChildItem "$policyKey\Scripts\Shutdown").Count | should be 1
            }
            It "Should keep shutdown State Scripts"{
                (Get-ChildItem "$policyKey\State\Machine\Scripts\Shutdown").Count | should be 1
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