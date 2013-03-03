$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.bootstrapper){Remove-Module boxstarter.bootstrapper}
Resolve-Path $here\..\boxstarter.common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\boxstarter.winconfig\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\boxstarter.bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
$Boxstarter.SuppressLogging=$true
$Boxstarter.BaseDir= (split-path -parent $here)

Describe "Invoke-Boxstarter" {
    $testRoot = (Get-PSDrive TestDrive).Root

    Context "When Configuration Service is installed" {
        Mock Test-Admin {return $true}
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Get-Service {new-Object -TypeName PSObject -Property @{CanStop=$True}} -ParameterFilter {$include -eq "CCMEXEC"}

        Invoke-Boxstarter {return}

        it "will stop ConfigurationService" {
            Assert-MockCalled Stop-Service -ParameterFilter {$name -eq "CCMEXEC"}
        }
        it "will start ConfigurationService" {
            Assert-MockCalled Start-Service -ParameterFilter {$name -eq "CCMEXEC"}
        }
    }

      Context "When Configuration Service is not installed" {
        Mock Test-Admin {return $true}
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Get-Service {$false} -ParameterFilter {$include -eq "CCMEXEC"}

        Invoke-Boxstarter {return}

        it "will stop just WUA" {
            Assert-MockCalled Stop-Service -ParameterFilter {$name -eq "wuauserv"}
        }
        it "will just start WUA" {
            Assert-MockCalled Start-Service -ParameterFilter {$name -eq "wuauserv"}
        }
    }

      Context "When An exception occurs in the install" {
        Mock Test-Admin {return $true}
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Get-Service {new-Object -TypeName PSObject -Property @{CanStop=$True}} -ParameterFilter {$include -eq "CCMEXEC"}

        try { Invoke-Boxstarter {throw "error"} } catch {}

        it "will stop WUA" {
            Assert-MockCalled Stop-Service -ParameterFilter {$name -eq "wuauserv"}
        }
        it "will stop CCM" {
            Assert-MockCalled Stop-Service -ParameterFilter {$name -eq "CCMEXEC"}
        }
    }
  
      Context "When A reboot is invoked" {
        Mock Get-UAC
        Mock Test-Admin {return $true}
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Set-SecureAutoLogon
        Mock Restart
        Mock RestartNow
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value 1

        Invoke-Boxstarter {Invoke-Reboot} -RebootOk -password (ConvertTo-SecureString "mypassword" -asplaintext -force)

        it "will save startup file" {
            Test-Path "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\boxstarter-post-restart.bat" | should Be $true
        }
        it "will not remove autologin registry" {
            (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon").AutoAdminLogon | should be 1
        }
        it "Will Save Script File" {
            "$env:temp\boxstarter.script" | should Contain "Invoke-Reboot"
        }
        it "Restart file will have RebootOk" {
            "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\boxstarter-post-restart.bat" | should Contain "-RebootOk"
        }
        remove-item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\boxstarter-post-restart.bat"
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon"
    }

    Context "When no password is provided but reboot is ok" {
        Mock Test-Admin {return $true}
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Set-SecureAutoLogon
        Mock Restart
        Mock RestartNow
        $pass=ConvertTo-SecureString "mypassword" -asplaintext -force
        Mock Read-AuthenticatedPassword {return $pass}
        Mock Get-UAC

        Invoke-Boxstarter {Invoke-Reboot} -RebootOk

        it "will read host for the password" {
            Assert-MockCalled Set-SecureAutoLogon -ParameterFilter {$password -eq $pass}
        }
        remove-item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\boxstarter-post-restart.bat"
    }

    Context "When no password is provided, reboot is ok and autologon is toggled" {
        Mock Test-Admin {return $true}
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Set-SecureAutoLogon
        Mock Restart
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        Mock get-UAC
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value 1

        Invoke-Boxstarter {Invoke-Reboot} -RebootOk

        it "will not read host for the password" {
            Assert-MockCalled Read-AuthenticatedPassword -times 0
        }
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon"
        remove-item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\boxstarter-post-restart.bat"
    }

    Context "When a password is provided and reboot is ok" {
        Mock Test-Admin {return $true}
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Set-SecureAutoLogon
        Mock Restart
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        Mock Disable-UAC

        Invoke-Boxstarter {return} -RebootOk -password (ConvertTo-SecureString "mypassword" -asplaintext -force)

        it "will not read host for the password" {
            Assert-MockCalled Read-AuthenticatedPassword -times 0
        }
    }

    Context "When reboot is not ok" {
        Mock Test-Admin {return $true}
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Set-SecureAutoLogon
        Mock Restart
        Mock RestartNow
        Mock Read-AuthenticatedPassword

        Invoke-Boxstarter {Invoke-Reboot}

        it "will not read host for the password" {
            Assert-MockCalled Read-AuthenticatedPassword -times 0
        }
        it "will not reboot" {
            Assert-MockCalled Restart -times 0
        }
    }

    Context "When ReEnableUAC File Exists" {
        Mock Test-Admin {return $true}
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Enable-UAC
        New-Item "$env:temp\BoxstarterReEnableUAC" -type file | Out-Null

        Invoke-Boxstarter {return}

        it "will Enable UAC" {
            Assert-MockCalled Enable-UAC
        }
        it "will Remove ReEnableUAC File" {
            "$env:temp\BoxstarterReEnableUAC" | Should Not Exist
        }
    }

    Context "When ReEnableUAC file does not exist" {
        Mock Test-Admin {return $true}
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Enable-UAC

        Invoke-Boxstarter {return}

        it "will Not Enable UAC" {
            Assert-MockCalled Enable-UAC -times 0
        }
    }

    Context "When Not Running As Admin" {
        Mock Test-Admin {return $false}
        Mock Start-Process
        Mock Stop-UpdateServices

        Invoke-Boxstarter {return}

        it "will Write Script File" {
            "$env:temp\boxstarter.script" | should Contain "return"
        }
        it "will invoke-boxstarter via elevated console"{
            Assert-MockCalled Start-Process -ParameterFilter {$filepath -eq "powershell" -and $verb -eq "runas" -and $argumentlist -like "*Invoke-BoxStarter*"}
        }
        it "will not stop update services" {
            Assert-MockCalled Stop-UpdateServices -times 0
        }
    }

    Context "When rebooting and No Password is set" {
        Mock Test-Admin {return $true}
        Mock Set-SecureAutoLogon
        Mock Stop-UpdateServices
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        $Boxstarter.IsRebooting=$true
        
        Invoke-Boxstarter {return} -RebootOk

        it "will Not Set AutoLogin" {
            Assert-MockCalled Set-SecureAutoLogon -times 0
        }
    }

    Context "When rebooting and a Password is set" {
        Mock Test-Admin {return $true}
        Mock Set-SecureAutoLogon
        Mock Stop-UpdateServices
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        $Boxstarter.IsRebooting=$true
        Mock Set-SecureAutoLogon

        Invoke-Boxstarter {return} -RebootOk -password (ConvertTo-SecureString "mypassword" -asplaintext -force)

        it "will Set AutoLogin" {
            Assert-MockCalled Set-SecureAutoLogon
        }
    }

    Context "When rebooting and UAC is Enabled and password is set" {
        Mock Test-Admin {return $true}
        Mock Set-SecureAutoLogon
        Mock Stop-UpdateServices
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        $Boxstarter.IsRebooting=$true
        Mock Get-UAC {return $true}
        Mock Disable-UAC
        Mock Set-SecureAutoLogon
        Mock New-Item

        Invoke-Boxstarter {return} -RebootOk -password (ConvertTo-SecureString "mypassword" -asplaintext -force)

        it "will Disable UAC" {
            Assert-MockCalled Disable-UAC
        }
        it "will add ReEnableUac file" {
            Assert-MockCalled New-Item -ParameterFilter {$path -like "*ReEnableUac*"}
        }
    }

    Context "When rebooting and UAC is Enabled and user has been auto loged on" {
        Mock Test-Admin {return $true}
        Mock Set-SecureAutoLogon
        Mock Stop-UpdateServices
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        $Boxstarter.IsRebooting=$true
        Mock Get-UAC {return $true}
        Mock Disable-UAC
        Mock Set-SecureAutoLogon
        Mock New-Item
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value 1

        Invoke-Boxstarter {return} -RebootOk

        it "will Disable UAC" {
            Assert-MockCalled Disable-UAC
        }
        it "will add ReEnableUac file" {
            Assert-MockCalled New-Item -ParameterFilter {$path -like "*ReEnableUac*"}
        }
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon"
    }

    Context "When rebooting UAC is enabled and password is not set" {
        Mock Test-Admin {return $true}
        Mock Set-SecureAutoLogon
        Mock Stop-UpdateServices
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        $Boxstarter.IsRebooting=$true
        Mock Get-UAC {return $true}
        Mock Disable-UAC
        Mock Set-SecureAutoLogon
        Mock New-Item
        
        Invoke-Boxstarter {return} -RebootOk

        it "will not Disable UAC" {
            Assert-MockCalled Disable-UAC -times 0
        }
        it "will not add ReEnableUac file" {
            Assert-MockCalled New-Item -ParameterFilter {$path -like "*ReEnableUac*"} -times 0
        }
    }

    Context "When rebooting and UAC is disabled" {
        Mock Test-Admin {return $true}
        Mock Set-SecureAutoLogon
        Mock Stop-UpdateServices
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        $Boxstarter.IsRebooting=$true
        Mock Get-UAC
        Mock Disable-UAC
        Mock Set-SecureAutoLogon
        Mock New-Item

        Invoke-Boxstarter {return} -RebootOk -password (ConvertTo-SecureString "mypassword" -asplaintext -force)

        it "will not Disable UAC" {
            Assert-MockCalled Disable-UAC -times 0
        }
        it "will not add ReEnableUac file" {
            Assert-MockCalled New-Item -ParameterFilter {$path -like "*ReEnableUac*"} -times 0
        }
    }
}