$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.bootstrapper){Remove-Module boxstarter.bootstrapper}
Resolve-Path $here\..\boxstarter.common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\boxstarter.winconfig\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\boxstarter.bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
$BoxstarterUser="user"
$Boxstarter.SuppressLogging=$true

Describe "Invoke-Reboot" {

    Context "When reboots are suppressed" {
        Mock New-Item
        Mock Restart
        $Boxstarter.RebootOk=$false
        $Boxstarter.IsRebooting=$false
        
        Invoke-Reboot

        it "will not create Restart file" {
            Assert-MockCalled New-Item -times 0
        }
        it "will not restart" {
            Assert-MockCalled Restart -times 0
        }
        it "will not toggle reboot" {
            $Boxstarter.IsRebooting | should be $false
        }
    }

    Context "When reboots are not suppressed" {
        Mock New-Item
        Mock Restart
        $Boxstarter.RebootOk=$true
        $Boxstarter.IsRebooting=$false

        Invoke-Reboot

        it "will create Restart file" {
            Assert-MockCalled New-Item
        }
        it "will restart" {
            Assert-MockCalled Restart
        }
        it "will toggle reboot" {
            $Boxstarter.IsRebooting | should be $true
        }
    }
}