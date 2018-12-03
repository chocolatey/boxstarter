$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe "Enable-BoxstarterVM" {
    Remove-Module boxstarter.*
    Resolve-Path $here\..\..\boxstarter.common\*.ps1 |
    % { . $_.ProviderPath }
    Resolve-Path $here\..\..\boxstarter.Chocolatey\*.ps1 |
    % { . $_.ProviderPath }
    Resolve-Path $here\..\..\boxstarter.HyperV\*.ps1 |
    % { . $_.ProviderPath }
    Remove-Item alias:\Enable-BoxstarterVM

    $Boxstarter.SuppressLogging=$true
    New-Item $env:temp\boxstarter.vhd -ItemType File -Force | Out-Null

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
    mock Restart-Computer
    Mock Set-VM
    Mock Get-VMIntegrationService { return @{ id="microsoft:blah\\84EAAE65-2F2E-45F5-9BB5-0E857DC8EB47";Name="Heartbeat";PrimaryStatusDescription="OK"} }
    Mock Get-VMGuestComputerName { "SomeComputer" }
    Mock Test-WSMan
    Mock Invoke-WmiMethod
    $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
    $mycreds = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)

    Context "When VM cannot be found"{

        Mock Get-VM

        try {
            Enable-BoxstarterVM -VMName Me -Credential $mycreds | Out-Null
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
            Assert-MockCalled Enable-BoxstarterVHD -parameterFilter { $IgnoreWMI -eq $null -and $IgnoreLocalAccountTokenFilterPolicy -eq $null}
        }
    }

    Context "When remoting is not enabled but wsman is responding"{
        Mock Get-VM { return @{State="Running";Name="me"} }
        Mock Enable-BoxstarterClientRemoting {return $True}
        Mock Invoke-Command
        Mock Test-WSMan { return New-Object -TypeName PSObject }
        Mock Get-VMGuestComputerName { "SomeComputer" }

        Enable-BoxstarterVM Me -Credential $mycreds | Out-Null

        It "Should Edit VHD but ignore wmi"{
            Assert-MockCalled Enable-BoxstarterVHD -parameterFilter { $IgnoreWMI -eq $true }
        }
    }

    Context "When remoting is not enabled but wmi is responding"{
        Mock Get-VM { return @{State="Running";Name="me"} }
        Mock Enable-BoxstarterClientRemoting {return $True}
        Mock Invoke-Command
        Mock Invoke-WmiMethod { return New-Object -TypeName PSObject }
        Mock Get-VMGuestComputerName { "SomeComputer" }

        Enable-BoxstarterVM Me -Credential $mycreds | Out-Null

        It "Should Edit VHD but ignore wmi"{
            Assert-MockCalled Enable-BoxstarterVHD -parameterFilter { $IgnoreWMI -eq $true }
        }
    }

    Context "When remoting is not enabled and WMI fails with an access exception"{
        Mock Get-VM { return @{State="Running";Name="me"} }
        Mock Enable-BoxstarterClientRemoting {return $True}
        Mock Invoke-Command
        Mock Invoke-WmiMethod { throw New-Object -TypeName UnauthorizedAccessException  }
        Mock Get-VMGuestComputerName { "SomeComputer" }

        try{Enable-BoxstarterVM Me -Credential $mycreds | Out-Null} catch{}

        It "Should Edit VHD but ignore wmi"{
            Assert-MockCalled Enable-BoxstarterVHD -parameterFilter { $IgnoreWMI -eq $true }
        }
    }

    Context "When remoting is not enabled but wsman is responding and no need to enable LocalAccountTokenFilterPolicy"{
        Mock Get-VM { return @{State="Running";Name="me"} }
        Mock Enable-BoxstarterClientRemoting {return $True}
        Mock Invoke-Command
        Mock Test-WSMan { return New-Object -TypeName PSObject }
        Mock Get-VMGuestComputerName { "SomeComputer" }
        $admincreds = New-Object System.Management.Automation.PSCredential ("administrator", $secpasswd)

        Enable-BoxstarterVM Me -Credential $admincreds | Out-Null

        It "Should not Edit VHD"{
            Assert-MockCalled Enable-BoxstarterVHD -times 0
        }
        It "Should not stop VM"{
            Assert-MockCalled Stop-VM -times 0
        }
    }

    Context "When remoting is not enabled and using administrator account"{
        Mock Get-VM { return @{State="Running";Name="me"} }
        Mock Enable-BoxstarterClientRemoting {return $True}
        Mock Invoke-Command
        Mock Get-VMGuestComputerName { "SomeComputer" }
        $admincreds = New-Object System.Management.Automation.PSCredential ("administrator", $secpasswd)

        Enable-BoxstarterVM Me -Credential $admincreds | Out-Null

        It "Should Edit VHD but ignore IgnoreLocalAccountTokenFilterPolicy"{
            Assert-MockCalled Enable-BoxstarterVHD -parameterFilter { $IgnoreLocalAccountTokenFilterPolicy -eq $true }
        }
    }

    Context "When remoting is not enabled and using administrator account in computer domain"{
        Mock Get-VM { return @{State="Running";Name="me"} }
        Mock Enable-BoxstarterClientRemoting {return $True}
        Mock Invoke-Command
        Mock Get-VMGuestComputerName { "SomeComputer" }
        $admincreds = New-Object System.Management.Automation.PSCredential ("SomeComputer\administrator", $secpasswd)

        Enable-BoxstarterVM Me -Credential $admincreds | Out-Null

        It "Should Edit VHD but ignore IgnoreLocalAccountTokenFilterPolicy"{
            Assert-MockCalled Enable-BoxstarterVHD -parameterFilter { $IgnoreLocalAccountTokenFilterPolicy -eq $true }
        }
    }

    Context "When remoting is not enabled and using domain account"{
        Mock Get-VM { return @{State="Running";Name="me"} }
        Mock Enable-BoxstarterClientRemoting {return $True}
        Mock Invoke-Command
        Mock Get-VMGuestComputerName { "SomeComputer" }
        $admincreds = New-Object System.Management.Automation.PSCredential ("SomeDomain\administrator", $secpasswd)

        Enable-BoxstarterVM Me -Credential $admincreds | Out-Null

        It "Should Edit VHD but ignore IgnoreLocalAccountTokenFilterPolicy"{
            Assert-MockCalled Enable-BoxstarterVHD -parameterFilter { $IgnoreLocalAccountTokenFilterPolicy -eq $true }
        }
    }

    Context "When remoting is enabled"{
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
        It "should return VM ConnectionURI" {
            $result.ConnectionURI | should be "http://SomeComputer:5985/wsman"
        }
        It "should return Credential" {
            $result.Credential | should be $mycreds
        }
    }
    Remove-Item $env:temp\boxstarter.vhd -Force
}
