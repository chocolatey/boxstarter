$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.bootstrapper){Remove-Module boxstarter.bootstrapper}
Resolve-Path $here\..\..\boxstarter.common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\boxstarter.winconfig\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\boxstarter.bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
$Boxstarter.SuppressLogging=$true
$Boxstarter.BaseDir=(split-path -parent (split-path -parent $here))

Describe "Test-PendingReboot" {
    $testRoot = (Get-PSDrive TestDrive).Root
   
	Context "When reboot is required" {
		Mock Get-PendingReboot { return new-Object -TypeName PSObject -Property @{ RebootPending=$True} }
        $reboot = Test-PendingReboot

        it "has invoked the Get-PendingReboot" {
            Assert-MockCalled Get-PendingReboot
        }

		it "will return true" {
			$reboot | should be $true
		}
    }

	Context "When reboot is NOT required" {
		Mock Get-PendingReboot { return new-Object -TypeName PSObject -Property @{ RebootPending=$False} }   
        $reboot = Test-PendingReboot

        it "has invoked the Get-PendingReboot" {
            Assert-MockCalled Get-PendingReboot
        }

		it "will return true" {
			$reboot | should be $false
		}
    }
}