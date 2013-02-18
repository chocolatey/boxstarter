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
    Context "When No Password is set" {
        Mock New-Item -ParameterFilter {$path -like "*Startup*"} -Verifiable
        Mock New-Item -ParameterFilter {$path -like "*.script"} -Verifiable
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
        Mock Get-UAC
        Mock New-Item -ParameterFilter {$path -like "*Startup*"} -Verifiable
        Mock New-Item -ParameterFilter {$path -like "*.script"} -Verifiable
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
        Mock New-Item
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

    Context "When UAC is Enabled and password is set" {
        $BoxstarterPassword= ConvertTo-SecureString "mypassword" -asplaintext -force
        Mock New-Item
        Mock Set-SecureAutoLogon
        Mock Restart
        $Boxstarter.RebootOk=$true
        Mock Get-UAC {return $true}
        Mock Disable-UAC
        
        Invoke-Reboot

        it "will Disable UAC" {
            Assert-MockCalled Disable-UAC
        }
        it "will add ReEnableUac file" {
            Assert-MockCalled New-Item -ParameterFilter {$path -like "*ReEnableUac*"}
        }
    }

    Context "When UAC is Enabled and user has been auto loged on" {
        $Boxstarter.AutologedOn=$true
        Mock New-Item
        Mock Set-SecureAutoLogon
        Mock Restart
        $Boxstarter.RebootOk=$true
        Mock Get-UAC {return $true}
        Mock Disable-UAC
        
        Invoke-Reboot

        it "will Disable UAC" {
            Assert-MockCalled Disable-UAC
        }
        it "will add ReEnableUac file" {
            Assert-MockCalled New-Item -ParameterFilter {$path -like "*ReEnableUac*"}
        }
    }

    Context "When UAC is enabled and password is not set" {
        Mock New-Item
        Mock Set-SecureAutoLogon
        Mock Restart
        $Boxstarter.RebootOk=$true
        Mock Get-UAC {return $false}
        Mock Disable-UAC
        
        Invoke-Reboot

        it "will not Disable UAC" {
            Assert-MockCalled Disable-UAC -times 0
        }
        it "will not add ReEnableUac file" {
            Assert-MockCalled New-Item -ParameterFilter {$path -like "*ReEnableUac*"} -times 0
        }
    }

    Context "When UAC is disabled" {
        Mock New-Item
        Mock Set-SecureAutoLogon
        Mock Restart
        $Boxstarter.RebootOk=$true
        Mock Get-UAC {return $false}
        Mock Disable-UAC
        
        Invoke-Reboot

        it "will not Disable UAC" {
            Assert-MockCalled Disable-UAC -times 0
        }
        it "will not add ReEnableUac file" {
            Assert-MockCalled New-Item -ParameterFilter {$path -like "*ReEnableUac*"} -times 0
        }
    }
}