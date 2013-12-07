$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe "Enable-BoxstarterVM" {
    Remove-Module boxstarter.*
    Resolve-Path $here\..\..\boxstarter.common\*.ps1 | 
    % { . $_.ProviderPath }
    Resolve-Path $here\..\..\boxstarter.virtualization\*.ps1 | 
    % { . $_.ProviderPath }
    Resolve-Path $here\..\..\boxstarter.Chocolatey\*.ps1 | 
    % { . $_.ProviderPath }
    $Boxstarter.SuppressLogging=$true
    New-Item $env:temp\boxstarter.vhd -ItemType File -Force | out-Null

    Mock Get-VM { return @{State="Running";Notes="--Boxstarter Remoting Enabled--";Name="me"} }
    Mock Get-VMSnapShot
    Mock Restore-VMSnapshot
    Mock Remove-VMSavedState
    Mock Stop-VM
    Mock Get-VMHardDiskDrive { return @{Path="$env:temp\boxstarter.vhd"} }
    Mock Enable-BoxstarterVHD
    Mock Start-VM
    Mock Enable-BoxstarterClientRemoting {return $True}
    Mock Invoke-Command
    Mock Checkpoint-VM
    Mock Set-VM
    Mock Get-VMIntegrationService { return @{ Name="Heartbeat";PrimaryStatusDescription="OK"} }
    Mock Get-VMGuestComputerName { "SomeComputer" }
    $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
    $mycreds = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)

    Context "When VM cannot be found"{

        Mock Get-VM

        try {
            Enable-BoxstarterVM Me -Credential $mycreds | Out-Null
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

        Enable-BoxstarterVM Me -Credential $mycreds -CheckPointName $snapshotName | Out-Null

        It "Should restore snapshot"{
            Assert-MockCalled Restore-VMSnapshot
        }
    }

    Context "When a checkpoint is specified that does not exists"{
        $snapshotName="snapshot"

        Enable-BoxstarterVM Me -Credential $mycreds -CheckPointName $snapshotName | Out-Null

        It "Should not restore snapshot"{
            Assert-MockCalled Restore-VMSnapshot -times 0
        }
        It "Should create snapshot"{
            Assert-MockCalled Checkpoint-VM -parameterFilter {$SnapshotName -eq $snapshotName -and $Name -eq "Me" }
        }
    }

    Context "When no checkpoint is specified"{

        Enable-BoxstarterVM Me -Credential $mycreds | Out-Null

        It "Should not restore snapshot"{
            Assert-MockCalled Restore-VMSnapshot -times 0
        }
        It "Should not create snapshot"{
            Assert-MockCalled Checkpoint-VM -times 0
        }
    }

    Context "When VM is in Saved state"{
        Mock Get-VM { @{State="Saved";Name="me"}}
        Enable-BoxstarterVM Me -Credential $mycreds | Out-Null

        It "Should remove vm saved state"{
            Assert-MockCalled Remove-VMSavedState
        }
    }

    Context "When remoting is not enabled"{
        Mock Get-VM { return @{State="Running";Name="me"} }
        Mock Enable-BoxstarterClientRemoting {return $True}
        Mock Invoke-Command
        Mock Get-VMGuestComputerName { "SomeComputer" }
        
        Enable-BoxstarterVM Me -Credential $mycreds | Out-Null

        It "Should Edit VHD"{
            Assert-MockCalled Enable-BoxstarterVHD
        }
    }

    Context "When remoting is enabled and Notes have not been written"{
        Mock Get-VM { return @{State="Running";Name="me"} }
        Mock Enable-BoxstarterClientRemoting {return $True}
        Mock Invoke-Command { return new-Object -TypeName PSObject }
        Mock Get-VMGuestComputerName { "SomeComputer" }
        
        $result = Enable-BoxstarterVM Me -Credential $mycreds

        It "Should not Edit VHD"{
            Assert-MockCalled Enable-BoxstarterVHD -times 0
        }
        It "Should not Stop VM"{
            Assert-MockCalled Stop-VM -times 0
        }
        It "should note that Boxstarter is enabled" {
            Assert-MockCalled set-VM -parameterFilter { $Notes -match "Boxstarter Remoting Enabled" }
        }
        It "should return VM ComputerName" {
            $result.ComputerName | should be "SomeComputer"
        }
        It "should return Credential" {
            $result.Credential | should be $mycreds
        }
    }

    Context "When remoting is enabled and Notes have not been written"{
        Mock Get-VM { return @{State="Running";Name="me";Notes="--Boxstarter Remoting Enabled--"} }
        Mock Enable-BoxstarterClientRemoting {return $True}
        Mock Invoke-Command { return new-Object -TypeName PSObject }
        Mock Get-VMGuestComputerName { "SomeComputer" }
        
        $result = Enable-BoxstarterVM Me -Credential $mycreds

        It "Should not Edit VHD"{
            Assert-MockCalled Enable-BoxstarterVHD -times 0
        }
        It "Should not Stop VM"{
            Assert-MockCalled Stop-VM -times 0
        }
        It "should not note that Boxstarter is enabled" {
            Assert-MockCalled set-VM -times 0
        }
        It "should return VM ComputerName" {
            $result.ComputerName | should be "SomeComputer"
        }
        It "should return Credential" {
            $result.Credential | should be $mycreds
        }
    }

    Context "When VM is Stopped AND NOTED enabled"{
        Mock Get-VM { return @{State="stopped";Name="me";Notes="--Boxstarter Remoting Enabled Box:Box1--"} }
        
        $result = Enable-BoxstarterVM Me -Credential $mycreds

        It "Should not Edit VHD"{
            Assert-MockCalled Enable-BoxstarterVHD -times 0
        }
        It "Should Start VM"{
            Assert-MockCalled Start-VM
        }
        It "should not note that Boxstarter is enabled" {
            Assert-MockCalled set-VM -times 0
        }
        It "should return VM ComputerName" {
            $result.ComputerName | should be "Box1"
        }
        It "should return Credential" {
            $result.Credential | should be $mycreds
        }
    }
    Remove-Item $env:temp\boxstarter.vhd -Force
}