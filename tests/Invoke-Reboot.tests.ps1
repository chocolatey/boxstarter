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
        $Password= ConvertTo-SecureString "mypassword" -asplaintext -force

        Invoke-Reboot

        it "will create Restart file and reboot" {
            Assert-VerifiableMocks
        }
        it "will Not Set AutoLogin" {
            Assert-MockCalled Set-SecureAutoLogon -times 1
        }
    }
}