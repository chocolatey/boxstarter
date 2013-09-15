$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\common.ps1"

Describe "Add-VHDStartupScript" {
    try{
        $TargetScriptDirectory = "Boxstarter.Startup"
        Import-Module "$here\..\..\Boxstarter.Virtualization\Boxstarter.Virtualization.psd1" -Force
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

        Context "When adding a startup script to a clean vhd" {

            Add-VHDStartupScript $testRoot\test.vhdx -FilesToCopy "$testRoot\file1.ps1","$testRoot\file2.ps1" {
                    function say-hi {"hi"}
                    say-hi
                } | Out-Null

            $vol = Mount-TestVHD
            It "Should create startup script"{
                & "$($vol.DriveLetter):\$TargetScriptDirectory\startup.bat" | should be "hi"
            }
            It "Should copy supporting scripts"{
                Test-Path "$($vol.DriveLetter):\$TargetScriptDirectory\file1.ps1" | should be $true
                Test-Path "$($vol.DriveLetter):\$TargetScriptDirectory\file2.ps1" | should be $true
            }
            It "Should set Group Policy"{
                (Get-ItemProperty -path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\0" -name Script).Script | should be "%SystemDrive%\$TargetScriptDirectory\startup.bat"
            }
            Clean-VHD
        }

        Context "When adding a startup script when another startup script exists" {
            Add-VHDStartupScript $testRoot\test.vhdx {
                    function say-hi {"hi"}
                    say-hi
                }
            $v = Mount-TestVHD
            Set-ItemProperty -path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\0" -name Script -value "%SystemDrive%\$TargetScriptDirectory\otherstartup.bat"
            [GC]::Collect()
            reg unload HKLM\VHDSYS | out-null
            Dismount-VHD $testRoot\test.vhdx

            Add-VHDStartupScript $testRoot\test.vhdx {
                    function say-hi {"hi"}
                    say-hi
                } | Out-Null

            $v = Mount-TestVHD
            It "Should add a new script in GPO"{
                (Get-ItemProperty -path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\1" -name Script).Script | should be "%SystemDrive%\$TargetScriptDirectory\startup.bat"
            }
            Clean-VHD
        }

        Context "When adding a startup script when another startup script exists but not in Local GPO" {
            Add-VHDStartupScript $testRoot\test.vhdx {
                    function say-hi {"hi"}
                    say-hi
                }
            $v = Mount-TestVHD
            Set-ItemProperty -path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0" -name DisplayName -value "Not Local"
            Set-ItemProperty -path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0" -name DisplayName -value "Not Local"
            [GC]::Collect()
            reg unload HKLM\VHDSYS | out-null
            Dismount-VHD $testRoot\test.vhdx
            Add-VHDStartupScript $testRoot\test.vhdx {
                    function say-hi {"hi"}
                    say-hi
                }
            $v = Mount-TestVHD
            Set-ItemProperty -path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0" -name DisplayName -value "Still Not Local"
            Set-ItemProperty -path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0" -name DisplayName -value "Still Not Local"
            [GC]::Collect()
            reg unload HKLM\VHDSYS | out-null
            Dismount-VHD $testRoot\test.vhdx

            Add-VHDStartupScript $testRoot\test.vhdx {
                    function say-hi {"hi"}
                    say-hi
                } | Out-Null

            $v = Mount-TestVHD
            It "Should add a Local GPO to position 0"{
                (Get-ItemProperty -path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0" -name DisplayName).DisplayName | should be "Local Group Policy"
            }
            It "Should Move Non Local GPO to position 1"{
                (Get-ItemProperty -path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\1" -name DisplayName).DisplayName | should be "Still Not Local"
            }
            It "Should Move Non Local GPO to position 2"{
                (Get-ItemProperty -path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\2" -name DisplayName).DisplayName | should be "Not Local"
            }
            It "Should add a Local GPO to state position 0"{
                (Get-ItemProperty -path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\0" -name DisplayName).DisplayName | should be "Local Group Policy"
            }
            It "Should Move Non Local GPO to state position 1"{
                (Get-ItemProperty -path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\1" -name DisplayName).DisplayName | should be "Still Not Local"
            }
            It "Should Move Non Local GPO to state position 2"{
                (Get-ItemProperty -path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\2" -name DisplayName).DisplayName | should be "Not Local"
            }
            Clean-VHD
        }

        Context "When adding a startup script when another startup script installed by this cmdlet exists" {
            Add-VHDStartupScript $testRoot\test.vhdx {
                    function say-hi {"hi"}
                    say-hi
                }

            Add-VHDStartupScript $testRoot\test.vhdx {
                    function say-hi {"hi"}
                    say-hi
                }

            $vol = Mount-TestVHD
            It "Should overwrite the current Script"{
                (Get-ItemProperty -path "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0\0" -name Script).Script | should be "%SystemDrive%\$TargetScriptDirectory\startup.bat"
            }
            It "Should not create a new script"{
                $dirs = Get-ChildItem "HKLM:\VHDSYS\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\0"
                $dirs.count | should be 1
            }
            $dirs=$null
            Clean-VHD
        }

        Context "When providing a nonexistent vhd path" {

            try {
                Add-VHDStartupScript $testRoot\notest.vhdx {
                    function say-hi {"hi"}
                    say-hi
                }
            }
            catch{
                $err = $_
            }

            It "Should throw a validation error"{
                $err.CategoryInfo.Category | should be "InvalidData"
            }
        }

        Context "When providing a nonexistent file to copy" {

            try {
                Add-VHDStartupScript $testRoot\test.vhdx -FilesToCopy "$testRoot\nofile1.ps1","$testRoot\nofile2.ps1" {
                    function say-hi {"hi"}
                    say-hi
                }
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
                Add-VHDStartupScript $env:SystemRoot {
                    function say-hi {"hi"}
                    say-hi
                }
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
                Add-VHDStartupScript $testRoot\test.vhdx {
                    function say-hi {"hi"}
                    say-hi
                }
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
                Add-VHDStartupScript $testRoot\test.vhdx {
                    function say-hi {"hi"}
                    say-hi
                }
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