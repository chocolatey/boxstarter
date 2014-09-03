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

Describe "Invoke-Boxstarter" {
    $testRoot = (Get-PSDrive TestDrive).Root
    $winUpdateKey="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
    Mock New-Item -ParameterFilter {$path -like "$env:appdata\*"}
    Mock New-ItemProperty -ParameterFilter { $path -eq $winUpdateKey }
    Mock Remove-ItemProperty -ParameterFilter { $path -eq $winUpdateKey }
    Mock Stop-Service
    Mock Start-Service
    Mock Set-Service
    Mock Enable-UAC
    Mock Disable-UAC
    Mock Start-Sleep
    Mock Get-Service {
            try{
                Assert-MockCalled Stop-Service -ParameterFilter {$name -eq "wuauserv"} -Times 0
                $called=$false
            }catch{
                $called=$true
            }
            if($called){
                return new-Object -TypeName PSObject -Property @{CanStop=$True;Status="Stopped"}
            }
            else {
                return new-Object -TypeName PSObject -Property @{CanStop=$True;Status="Running"}
            }
    } -ParameterFilter {$Name -eq "wuauserv"}

    Context "When no password is provided, reboot is ok and autologon is toggled" {
        Mock Set-SecureAutoLogon
        Mock Restart
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        Mock get-UAC
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value 1
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoLogonCount" -Value 1

        Invoke-Boxstarter {Invoke-Reboot} -RebootOk | Out-Null

        it "will not read host for the password" {
            Assert-MockCalled Read-AuthenticatedPassword -times 0
        }
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon"
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoLogonCount"
    }

    Context "When Configuration Service is installed" {
        Mock Get-Service {new-Object -TypeName PSObject -Property @{CanStop=$True}} -ParameterFilter {$include -eq "CCMEXEC"}

        Invoke-Boxstarter {return} | Out-Null

        it "will disable WUA" {
            Assert-MockCalled New-ItemProperty -ParameterFilter { $path -eq $winUpdateKey }
        }
        it "will enable WUA" {
            Assert-MockCalled Remove-ItemProperty -ParameterFilter { $path -eq $winUpdateKey }
        }
        it "will stop ConfigurationService" {
            Assert-MockCalled Stop-Service -ParameterFilter {$name -eq "CCMEXEC"}
        }
        it "will start ConfigurationService" {
            Assert-MockCalled Start-Service -ParameterFilter {$name -eq "CCMEXEC"}
        }
    }

      Context "When Configuration Service is not installed" {
        Mock Get-Service {$false} -ParameterFilter {$include -eq "CCMEXEC"}

        Invoke-Boxstarter {return} | Out-Null

        it "will disable WUA" {
            Assert-MockCalled New-ItemProperty -ParameterFilter { $path -eq $winUpdateKey }
        }
        it "will enable WUA" {
            Assert-MockCalled Remove-ItemProperty -ParameterFilter { $path -eq $winUpdateKey }
        }
        it "will not stop ConfigurationService" {
            Assert-MockCalled Stop-Service -ParameterFilter {$name -eq "CCMEXEC"} -Times 0
        }
        it "will not start ConfigurationService" {
            Assert-MockCalled Start-Service -ParameterFilter {$name -eq "CCMEXEC"} -Times 0
        }
    }

      Context "When An exception occurs in the install" {
        Mock Get-Service {new-Object -TypeName PSObject -Property @{CanStop=$True}} -ParameterFilter {$include -eq "CCMEXEC"}

        try { Invoke-Boxstarter { throw "error" } | Out-Null } catch {}

        it "will disable WUA" {
            Assert-MockCalled New-ItemProperty -ParameterFilter { $path -eq $winUpdateKey }
        }
        it "will stop CCM" {
            Assert-MockCalled Stop-Service -ParameterFilter {$name -eq "CCMEXEC"}
        }
    }

    Context "When install is remote and invokes task" {
        Mock Get-IsRemote {$true}

        Invoke-Boxstarter { Invoke-FromTask "add-content $env:temp\test.txt -value '`$pid'" } -NoPassword | Out-Null
        $boxProc=get-Content $env:temp\test.txt
        Remove-item $env:temp\test.txt

        it "will run in a different process" {
            $boxProc | should not be $pid
        }
        it "will delete task" {
            ($result=schtasks.exe /query /TN "Boxstarter Task") 2>&1 | Out-Null
            $result[0] | should Match "ERROR:"
        }
    }
  
      Context "When A reboot is invoked" {
        Mock Get-UAC
        Mock Set-SecureAutoLogon
        Mock Restart
        Mock RestartNow
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value 1

        Invoke-Boxstarter {Invoke-Reboot} -RebootOk -password (ConvertTo-SecureString "mypassword" -asplaintext -force) | Out-Null

        it "will save startup file" {
            Assert-MockCalled New-Item -ParameterFilter {$Path -eq "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\boxstarter-post-restart.bat"}
        }
        it "will not remove autologin registry" {
            (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon").AutoAdminLogon | should be 1
        }
        it "Will Save Script File" {
            Assert-MockCalled New-Item -ParameterFilter {$Path -eq "$(Get-BoxstarterTempDir)\boxstarter.script" -and ($Value -like "*Invoke-Reboot*")}
        }
        it "Restart file will have RebootOk" {
            Assert-MockCalled New-Item -ParameterFilter {$Path -eq "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\boxstarter-post-restart.bat" -and ($Value -like "*-RebootOk*")}
        }
        it "Restart file will have NoPassword Set To False" {
            Assert-MockCalled New-Item -ParameterFilter {$Path -eq "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\boxstarter-post-restart.bat" -and ($Value -like "*-NoPassword:`$False*")}
        }
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon"
    }

    Context "When no password is provided but reboot is ok" {
        Mock Set-SecureAutoLogon
        Mock Restart
        Mock RestartNow
        $pass=ConvertTo-SecureString "mypassword" -asplaintext -force
        Mock Read-AuthenticatedPassword {return $pass}
        Mock Get-UAC

        Invoke-Boxstarter {Invoke-Reboot} -RebootOk | Out-Null

        it "will read host for the password" {
            Assert-MockCalled Set-SecureAutoLogon -ParameterFilter {$password -eq $pass}
        }
    }

    Context "When no script is passed on command line but script file exists" {
        Mock Set-SecureAutoLogon
        Mock Restart
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        Mock get-UAC
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value 1
        New-Item "$(Get-BoxstarterTempDir)\Boxstarter.script" -type file -value ([ScriptBlock]::Create("`$env:testkey='val'")) -force | Out-Null

        Invoke-Boxstarter -RebootOk | Out-Null

        it "will call script" {
            $env:testkey | should be "val"
        }
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
    }

    Context "When a password is provided and reboot is ok" {
        Mock Set-SecureAutoLogon
        Mock Restart
        Mock RestartNow
        Mock Read-AuthenticatedPassword

        Invoke-Boxstarter {return} -RebootOk -password (ConvertTo-SecureString "mypassword" -asplaintext -force) | Out-Null

        it "will not read host for the password" {
            Assert-MockCalled Read-AuthenticatedPassword -times 0
        }
        $script:BoxstarterPassword=$null
    }

    Context "When the NoPassword switch is specified and reboot is ok" {
        Mock Set-SecureAutoLogon
        Mock Restart
        Mock RestartNow
        Mock Read-AuthenticatedPassword

        Invoke-Boxstarter {Invoke-Reboot} -RebootOk -NoPassword | Out-Null

        it "will not read host for the password" {
            Assert-MockCalled Read-AuthenticatedPassword -times 0
        }
        it "Restart file will specify NoPassword" {
            Assert-MockCalled New-Item -ParameterFilter {$Path -eq "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\boxstarter-post-restart.bat" -and ($Value -like "*-NoPassword:`$True*")}
        }
    }

    Context "When reboot is not ok" {
        $Boxstarter.RebootOk=$false
        Mock Set-SecureAutoLogon
        Mock Restart
        Mock RestartNow
        Mock Read-AuthenticatedPassword

        Invoke-Boxstarter {Invoke-Reboot} | Out-Null

        it "will not read host for the password" {
            Assert-MockCalled Read-AuthenticatedPassword -times 0
        }
        it "will not reboot" {
            Assert-MockCalled Restart -times 0
        }
    }

    Context "When boxstarter.rebootok is set but not passed to command" {
        Mock Set-SecureAutoLogon
        Mock Restart
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        $Boxstarter.RebootOk=$true

        Invoke-Boxstarter {Invoke-Reboot} | Out-Null

        it "will reboot" {
            Assert-MockCalled Restart
        }
        $Boxstarter.RebootOk=$False
    }

    Context "When ReEnableUAC File Exists" {
        New-Item "$(Get-BoxstarterTempDir)\BoxstarterReEnableUAC" -type file -Force | Out-Null

        Invoke-Boxstarter {return} | Out-Null

        it "will Enable UAC" {
            Assert-MockCalled Enable-UAC
        }
        it "will Remove ReEnableUAC File" {
            "$(Get-BoxstarterTempDir)\BoxstarterReEnableUAC" | Should Not Exist
        }
    }

    Context "When ReEnableUAC file does not exist" {

        Invoke-Boxstarter {return} | Out-Null

        it "will Not Enable UAC" {
            Assert-MockCalled Enable-UAC -times 0
        }
    }

    Context "When Not Running As Admin" {
        Mock Stop-UpdateServices
        Mock Test-Admin
        Mock Start-Process

        Invoke-Boxstarter {return} | Out-Null

        it "will Write Script File" {
            "$(Get-BoxstarterTempDir)\boxstarter.script" | should Contain "return"
        }
        it "will invoke-boxstarter via elevated console"{
            Assert-MockCalled Start-Process -ParameterFilter {$filepath -eq "powershell" -and $verb -eq "runas" -and $argumentlist -like "*Invoke-BoxStarter*"}
        }
        it "will not stop update services" {
            Assert-MockCalled Stop-UpdateServices -times 0
        }
    }

    Context "When Not Running As Admin and passing a password arg" {
        Mock Stop-UpdateServices
        Mock Start-Process
        $securePassword = (ConvertTo-SecureString "mypassword" -asplaintext -force)
        Mock Test-Admin

        Invoke-Boxstarter {return} -password $securePassword | Out-Null

        it "will pass password to elevated console encryptedPassword arg"{
            Assert-MockCalled Start-Process -ParameterFilter {$argumentlist -like "*-encryptedPassword *"}
        }
    }

    Context "When rebooting and No Password is set" {
        Mock Set-SecureAutoLogon
        Mock Stop-UpdateServices
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        $Boxstarter.IsRebooting=$true
        
        Invoke-Boxstarter {return} -RebootOk | Out-Null

        it "will Not Set AutoLogin" {
            Assert-MockCalled Set-SecureAutoLogon -times 0
        }
    }

    Context "When rebooting and a Password is set" {
        Mock Stop-UpdateServices
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        Mock Set-SecureAutoLogon

        Invoke-Boxstarter {$Boxstarter.IsRebooting=$true} -RebootOk -password (ConvertTo-SecureString "mypassword" -asplaintext -force) | Out-Null

        it "will Set AutoLogin" {
            Assert-MockCalled Set-SecureAutoLogon -ParameterFilter {$BackupFile -eq "$(Get-BoxstarterTempDir)\boxstarter.autologon"}
        }
    }

    Context "When rebooting and a Password is set and in remote session" {
        Mock Stop-UpdateServices
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        Mock Set-SecureAutoLogon
        Mock Get-IsRemote {return $true}
        Mock Create-BoxstarterTask

        Invoke-Boxstarter {$Boxstarter.IsRebooting=$true} -RebootOk -password (ConvertTo-SecureString "mypassword" -asplaintext -force) | Out-Null

        it "will Not Set AutoLogin" {
            Assert-MockCalled Set-SecureAutoLogon -times 0
        }
    }

    Context "When rebooting and UAC is Enabled" {
        Mock Stop-UpdateServices
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        Mock Get-UAC {return $true}
        Mock Set-SecureAutoLogon
        Mock New-Item

        Invoke-Boxstarter {$Boxstarter.IsRebooting=$true} -RebootOk | Out-Null

        it "will Disable UAC" {
            Assert-MockCalled Disable-UAC
        }
        it "will add ReEnableUac file" {
            Assert-MockCalled New-Item -ParameterFilter {$path -like "*ReEnableUac*"}
        }
    }

    Context "When rebooting UAC is enabled and in remote session" {
        Mock Stop-UpdateServices
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        $Boxstarter.IsRebooting=$true
        Mock Get-UAC {return $true}
        Mock Set-SecureAutoLogon
        Mock New-Item
        Mock Get-IsRemote {return $true}
        Mock Create-BoxstarterTask

        Invoke-Boxstarter {return} -RebootOk | Out-Null

        it "will not Disable UAC" {
            Assert-MockCalled Disable-UAC -times 0
        }
        it "will not add ReEnableUac file" {
            Assert-MockCalled New-Item -ParameterFilter {$path -like "*ReEnableUac*"} -times 0
        }
    }

    Context "When rebooting and UAC is disabled" {
        Mock Stop-UpdateServices
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        $Boxstarter.IsRebooting=$true
        Mock Get-UAC
        Mock Set-SecureAutoLogon
        Mock New-Item

        Invoke-Boxstarter {return} -RebootOk -password (ConvertTo-SecureString "mypassword" -asplaintext -force) | Out-Null

        it "will not Disable UAC" {
            Assert-MockCalled Disable-UAC -times 0
        }
        it "will not add ReEnableUac file" {
            Assert-MockCalled New-Item -ParameterFilter {$path -like "*ReEnableUac*"} -times 0
        }
    }

    Context "When not rebooting and empty autologon backup exists" {
        Mock Start-Process
        Mock Stop-UpdateServices
        Mock RestartNow
        Mock Read-AuthenticatedPassword
        Mock Get-UAC
        Mock Remove-ItemProperty
        Mock Get-ItemProperty -ParameterFilter { $path -eq $winUpdateKey } -MockWith {@{
            DefaultUserName = $true
            DefaultDomainName = $true
            DefaultPassword = $true
            AutoAdminLogon = $true
        }}
        New-Item "$(Get-BoxstarterTempDir)\Boxstarter.autologon" -type file -Force | Out-Null

        Invoke-Boxstarter {return} -RebootOk | Out-Null

        it "will remove autologon DefaultUserName" {
            Assert-MockCalled Remove-ItemProperty -ParameterFilter { $path -eq $winUpdateKey -and $Name -eq "DefaultUserName" }
        }
        it "will remove autologon DefaultDomainName" {
            Assert-MockCalled Remove-ItemProperty -ParameterFilter { $path -eq $winUpdateKey -and $Name -eq "DefaultDomainName" }
        }
        it "will remove autologon DefaultPassword" {
            Assert-MockCalled Remove-ItemProperty -ParameterFilter { $path -eq $winUpdateKey -and $Name -eq "DefaultPassword" }
        }
        it "will remove autologon AutoAdminLogon" {
            Assert-MockCalled Remove-ItemProperty -ParameterFilter { $path -eq $winUpdateKey -and $Name -eq "AutoAdminLogon" }
        }
    }    
}