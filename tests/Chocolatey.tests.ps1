$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter){Remove-Module boxstarter}
Resolve-Path $here\..\bootstrapper\*.ps1 | 
    ? { -not ($_.ProviderPath.Contains("AdminProxy")) } |
    % { . $_.ProviderPath }

Describe "Getting Chocolatey" {
    Context "When a reboot is pending and reboots are ok" {
        Mock Call-Chocolatey
        Mock Test-PendingReboot {$true}
        $boxstarter.RebootOk=$true
        Mock Invoke-Reboot
        
        Chocolatey Install pkg

        it "will Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 1
        }
        it "will not get chocolatry" {
            Assert-MockCalled Call-Chocolatey -times 0
        }        
    }

    Context "When a reboot is pending but reboots are not ok" {
        Mock Call-Chocolatey
        Mock Test-PendingReboot {$true}
        $boxstarter.RebootOk=$false
        Mock Invoke-Reboot
        
        Chocolatey Install pkg

        it "will not Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 0
        }
        it "will get chocolatry" {
            Assert-MockCalled Call-Chocolatey -times 1
        }        
    }

    Context "When a reboot is not pending" {
        Mock Call-Chocolatey
        Mock Test-PendingReboot {return $false}
        Mock Invoke-Reboot
        
        Chocolatey Install pkg

        it "will not Invoke-Reboot" {
            Assert-MockCalled Invoke-Reboot -times 0
        }
        it "will get chocolatry" {
            Assert-MockCalled Call-Chocolatey -times 1
        }        
    }
}