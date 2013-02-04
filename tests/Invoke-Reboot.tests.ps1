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
        Mock Get-UAC
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

    Context "When UAC is Enabled and password is set" {
        if(!(get-module Boxstarter.Helpers)){
            Import-Module $here\..\Helpers\Boxstarter.Helpers.psm1
        }
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
        it "will add ReEnableUac to restart command" {
            Assert-MockCalled New-Item -ParameterFilter {$value -like "*-ReEnableUac"}
        }
        Write-Host $myPath
    }

    Context "When UAC is Enabled and user has been auto loged on" {
        if(!(get-module Boxstarter.Helpers)){
            Import-Module $here\..\Helpers\Boxstarter.Helpers.psm1
        }
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
        it "will add ReEnableUac to restart command" {
            Assert-MockCalled New-Item -ParameterFilter {$value -like "*-ReEnableUac"}
        }
        Write-Host $myPath
    }

    Context "When UAC is enabled and password is not set" {
        if(!(get-module Boxstarter.Helpers)){
            Import-Module $here\..\Helpers\Boxstarter.Helpers.psm1
        }
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
        it "will not add ReEnableUac to restart command" {
            Assert-MockCalled New-Item -ParameterFilter {$path -like "*-ReEnableUac*"} -times 0
        }
    }

    Context "When UAC is disabled" {
        if(!(get-module Boxstarter.Helpers)){
            Import-Module $here\..\Helpers\Boxstarter.Helpers.psm1
        }
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
        it "will not add ReEnableUac to restart command" {
            Assert-MockCalled New-Item -ParameterFilter {$path -like "*-ReEnableUac*"} -times 0
        }
    }
}