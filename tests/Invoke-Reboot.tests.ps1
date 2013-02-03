$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter){Remove-Module boxstarter}
Resolve-Path $here\..\bootstrapper\*.ps1 | 
    ? { -not ($_.ProviderPath.Contains("AdminProxy")) } |
    % { . $_.ProviderPath }

Describe "Invoke-Reboot" {
    Context "When No Password is set" {
        Mock New-Item -ParameterFilter {$path -like "*Startup*"} -Verifiable
        Mock Set-SecureAutoLogon
        Mock Restart -Verifiable
        $Boxstarter.RebootOk=$true
        
        Invoke-Reboot

        it "will create Restart file and reboot" {
            Assert-VerifiableMocks
        }
        it "will Not Set AutoLogin" {
            Assert-MockCalled Set-SecureAutoLogon -times 0
        }
    }

    Context "When a Password is set" {
        Mock New-Item -ParameterFilter {$path -like "*Startup*"} -Verifiable
        Mock Set-SecureAutoLogon
        Mock Restart -Verifiable
        $BoxstarterPassword= ConvertTo-SecureString "mypassword" -asplaintext -force
        $Boxstarter.RebootOk=$true

        Invoke-Reboot

        it "will create Restart file and reboot" {
            Assert-VerifiableMocks
        }
        it "will Set AutoLogin" {
            Assert-MockCalled Set-SecureAutoLogon -times 1
        }
    }

    Context "When reboots are suppressed" {
        Mock New-Item -ParameterFilter {$path -like "*Startup*"}
        Mock Set-SecureAutoLogon
        Mock Restart
        $BoxstarterPassword= ConvertTo-SecureString "mypassword" -asplaintext -force
        $Boxstarter.RebootOk=$false
        
        Invoke-Reboot

        it "will not create Restart file" {
            Assert-MockCalled New-Item -times 0
        }
        it "will Not Set AutoLogin" {
            Assert-MockCalled Set-SecureAutoLogon -times 0
        }
        it "will not restart" {
            Assert-MockCalled Restart -times 0
        }
    }
}