$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe "Enable-BoxstarterVM" {
    Remove-Module boxstarter.*
    Resolve-Path $here\..\..\boxstarter.common\*.ps1 | 
    % { . $_.ProviderPath }
    Resolve-Path $here\..\..\boxstarter.virtualization\*.ps1 | 
    % { . $_.ProviderPath }
    $Boxstarter.SuppressLogging=$true

    Mock Get-VM { return @{State="Running"} }
    Mock Get-VMSnapShot
    Mock Restore-VMSnapshot
    Mock Remove-VMSavedState
    Mock Stop-VM
    Mock Get-VMHardDiskDrive { return @{Path="$env:temp\boxstarter.vhd"} }
    New-Item $env:temp\boxstarter.vhd -ItemType File -Force
    Mock Enable-BoxstarterVHD
    Mock Start-VM
    Mock Checkpoint-VM
    Mock Get-VMIntegrationService { return @{ Name="Heartbeat";PrimaryStatusDescription="OK"} }

    Context "When VM cannot be found"{

        Mock Get-VM

        try {
            Enable-BoxstarterVM Me | Out-Null
        }
        catch{
            $err = $_
        }

        It "Should throw a InvalidOperation Exception"{
            $err.CategoryInfo.Reason | should be "InvalidOperationException"
        }
    }

    Context "When a checkpoint is specified that exists"{
        $snapshotName="snapshot"
        Mock Get-VMSnapShot { "I am a snapshot" } -parameterFilter {$Name -eq $snapshotName}

        Enable-BoxstarterVM Me -CheckPointName $snapshotName | Out-Null

        It "Should restore snapshot"{
            Assert-MockCalled Restore-VMSnapshot
        }
    }

    Context "When a checkpoint is specified that does not exists"{
        $snapshotName="snapshot"

        Enable-BoxstarterVM Me -CheckPointName $snapshotName | Out-Null

        It "Should not restore snapshot"{
            Assert-MockCalled Restore-VMSnapshot -times 0
        }
        It "Should create snapshot"{
            Assert-MockCalled Checkpoint-VM -parameterFilter {$SnapshotName -eq $snapshotName -and $Name -eq "Me" }
        }
    }

    Context "When no checkpoint is specified"{

        Enable-BoxstarterVM Me | Out-Null

        It "Should not restore snapshot"{
            Assert-MockCalled Restore-VMSnapshot -times 0
        }
        It "Should not create snapshot"{
            Assert-MockCalled Checkpoint-VM -times 0
        }
    }

    Context "When VM is in Saved state"{
        Mock Get-VM { @{State="Saved"}}
        Enable-BoxstarterVM Me | Out-Null

        It "Should remove vm saved state"{
            Assert-MockCalled Remove-VMSavedState
        }
    }
    Remove-Item $env:temp\boxstarter.vhd -Force
}