$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Mount-TestVHD {
    $testRoot="$env:temp\Boxstarter.tests"
    $before = (Get-Volume).DriveLetter
    Mount-VHD $testRoot\test.vhdx
    $after = (Get-Volume).DriveLetter
    $winVolume = compare $before $after -Passthru
    Get-PSDrive | Out-Null
    reg load HKLM\VHDSYS "$($winVolume):\windows\system32\config\system" 2>&1 | out-null
    reg load HKLM\VHDSOFTWARE "$($winVolume):\windows\system32\config\software" 2>&1 | out-null
}

function Clean-VHD {
    [GC]::Collect()
    $vol = Get-Volume | ? {$_.FileSystemLabel -eq "VHD"}
    reg unload HKLM\VHDSYS | Out-Null
    reg unload HKLM\VHDSOFTWARE | Out-Null
    Remove-Item "$($vol.DriveLetter):\Windows\System32\config\SOFTWARE"
    reg save HKLM\Software "$($vol.DriveLetter):\Windows\System32\config\SOFTWARE" /y /c | Out-Null
    Remove-Item "$($vol.DriveLetter):\Windows\System32\config\System"
    reg save HKLM\System "$($vol.DriveLetter):\Windows\System32\config\System" /y /c | Out-Null
    Dismount-VHD "$env:temp\Boxstarter.tests\test.vhdx"
}

Describe "Enable-BoxstarterVHD" {
    try{
        Remove-Module boxstarter.*
        Resolve-Path $here\..\..\boxstarter.common\*.ps1 | 
        % { . $_.ProviderPath }
        Resolve-Path $here\..\..\boxstarter.virtualization\*.ps1 | 
        % { . $_.ProviderPath }
        $Boxstarter.SuppressLogging=$true
        mkdir $env:temp\Boxstarter.tests -force | Out-Null
        $testRoot="$env:temp\Boxstarter.tests"
        $v = new-vhd -Path $testRoot\test.vhdx -SizeBytes 200MB | 
          Mount-VHD -PassThru | 
          Initialize-Disk -PartitionStyle mbr -Confirm:$false -PassThru | 
          New-Partition -UseMaximumSize -AssignDriveLetter -MbrType IFS | 
          Format-Volume -NewFileSystemLabel "VHD" -Confirm:$false
        Get-PSDrive | Out-Null
        mkdir "$($v.DriveLetter):\Windows\System32\config" | Out-Null
        reg save HKLM\Software "$($v.DriveLetter):\Windows\System32\config\SOFTWARE" /y /c | Out-Null
        reg save HKLM\System "$($v.DriveLetter):\Windows\System32\config\System" /y /c | Out-Null
        Dismount-VHD $testRoot\test.vhdx

        Context "When enabling a vhd with disabled firewall and LocalAccountTokenFilterPolicy" {
            Mount-TestVHD
            $computerName="SomeComputer"
            $current=Get-CurrentControlSet
            Disable-FireWallRule WMI-RPCSS-In-TCP
            Disable-FireWallRule WMI-WINMGMT-In-TCP
            Remove-ItemProperty -path "HKLM:\VHDSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\system" -name LocalAccountTokenFilterPolicy -ErrorAction SilentlyContinue
            Set-ItemProperty -path "HKLM:\VHDSYS\ControlSet00$current\Control\ComputerName\ComputerName" -Name ComputerName -value "$computerName"
            [GC]::Collect()
            reg unload HKLM\VHDSYS | out-null
            reg unload HKLM\VHDSOFTWARE | out-null
            Dismount-VHD $testRoot\test.vhdx

            $result = Enable-BoxstarterVHD $testRoot\test.vhdx

            Mount-TestVHD
            It "Should set LocalAccountTokenFilterPolicy"{
                (Get-ItemProperty -path "HKLM:\VHDSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\system" -name LocalAccountTokenFilterPolicy) | should be 1
            }
            It "Should Get ComputerName" {
                $result| should be $computerName
            }
            It "Should set WMI-RPCSS-In-TCP Rule"{
                $rules = Get-ItemProperty -path (Get-FirewallKey)
                $rules.'WMI-RPCSS-In-TCP' | Should Match "|Active=TRUE|"
            }
            It "Should set WMI-WINMGMT-In-TCP Rule"{
                $rules = Get-ItemProperty -path (Get-FirewallKey)
                $rules.'WMI-WINMGMT-In-TCP' | Should Match "|Active=TRUE|"
            }
            Clean-VHD
        }
    }
    finally{
        [GC]::Collect()
        reg unload HKLM\VHDSYS 2>&1 | Out-Null
        reg unload HKLM\VHDSOFTWARE 2>&1 | Out-Null
        if(Test-Path $testRoot\test.vhdx){
            Dismount-VHD $testRoot\test.vhdx -ErrorAction SilentlyContinue
            Remove-Item $testRoot\test.vhdx
        }
        del $env:temp\Boxstarter.tests -recurse -force
    }
}