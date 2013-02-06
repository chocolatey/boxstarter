$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter){Remove-Module boxstarter}
if(get-module Boxstarter.Helpers){Remove-Module boxstarter.Helpers}
Import-Module $here\..\Helpers\Boxstarter.Helpers.psm1
$BoxstarterUser="user"

Describe "Invoke-Boxstarter via bootstrapper.bat (end to end)" {
    ."$here\..\build.bat" Pack-Nuget
    $testRoot = (Get-PSDrive TestDrive).Root
    mkdir "$testRoot\Repo" -ErrorAction ignore
    Copy-Item $here\..\BuildArtifacts\Boxstarter.Helpers.*.nupkg "$testRoot\Repo"
    Copy-Item $here\..\BuildArtifacts\test-package.*.nupkg "$testRoot\Repo"

    Context "When installing a local package" {
        remove-Item "$env:ChocolateyInstall\lib\test-package.*" -force -recurse
        remove-Item "$env:ChocolateyInstall\lib\boxstarter.helpers.*" -force -recurse
        Add-Content "$env:ChocolateyInstall\ChocolateyInstall\ChocolateyInstall.log" -Value "______ test-package v1.0.0 ______" -force

        ."$here\..\boxstarter.bat" test-package -LocalRepo "$testRoot\Repo"

        it "should save boxstarter package to chocolatey lib folder" {
            Test-Path "$env:ChocolateyInstall\lib\test-package.*" | Should Be $true
        }
        it "should save helper package to chocolatey lib folder" {
            Test-Path "$env:ChocolateyInstall\lib\boxstarter.helpers.*" | Should Be $true
        }
        it "should have cleared previous logs" {
            $installLines = get-content "$env:ChocolateyInstall\ChocolateyInstall\ChocolateyInstall.log" | ? { $_ -eq "______ test-package v1.0.0 ______" } 
            $installLines.Count | Should Be 1
        }          
    }
}
Resolve-Path $here\..\bootstrapper\*.ps1 | 
    ? { -not ($_.ProviderPath.Contains("AdminProxy")) } |
    % { . $_.ProviderPath }

Describe "Invoke-Boxstarter" {
    $testRoot = (Get-PSDrive TestDrive).Root

    Context "When Configuration Service is installed" {
        Mock Check-Chocolatey
        Mock Chocolatey
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Get-Service {new-Object -TypeName PSObject -Property @{CanStop=$True}} -ParameterFilter {$include -eq "CCMEXEC"}

        Invoke-Boxstarter test-package

        it "will stop ConfigurationService" {
            Assert-MockCalled Stop-Service -ParameterFilter {$name -eq "CCMEXEC"}
        }
        it "will start ConfigurationService" {
            Assert-MockCalled Start-Service -ParameterFilter {$name -eq "CCMEXEC"}
        }
    }

      Context "When Configuration Service is not installed" {
        Mock Check-Chocolatey
        Mock Chocolatey
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Get-Service {$false} -ParameterFilter {$include -eq "CCMEXEC"}

        Invoke-Boxstarter test-package

        it "will stop just WUA" {
            Assert-MockCalled Stop-Service -ParameterFilter {$name -eq "wuauserv"}
        }
        it "will just start WUA" {
            Assert-MockCalled Start-Service -ParameterFilter {$name -eq "wuauserv"}
        }
    }

      Context "When An exception occurs in the install" {
        Mock Check-Chocolatey
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Get-Service {new-Object -TypeName PSObject -Property @{CanStop=$True}} -ParameterFilter {$include -eq "CCMEXEC"}
        Mock Chocolatey {throw "error"}

        try { Invoke-Boxstarter test-package } catch {}

        it "will stop WUA" {
            Assert-MockCalled Stop-Service -ParameterFilter {$name -eq "wuauserv"}
        }
        it "will stop CCM" {
            Assert-MockCalled Stop-Service -ParameterFilter {$name -eq "CCMEXEC"}
        }
    }
  
      Context "When A reboot is invoked" {
        Mock Get-UAC
        Mock Check-Chocolatey
        Mock Call-Chocolatey
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Set-SecureAutoLogon
        Mock Restart
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value 1
        Mock Test-PendingReboot {return $true}

        Invoke-Boxstarter test-package -RebootOk -password (ConvertTo-SecureString "mypassword" -asplaintext -force) -LocalRepo "c:\someRepo"

        it "will not delete startup file" {
            Test-Path "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat" | should Be $true
        }
        it "will not remove autologin registry" {
            (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon").AutoAdminLogon | should be 1
        }
        it "Restart file will have package name" {
            "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat" | should Contain "test-package"
        }
        it "Restart file will have RebootOk" {
            "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat" | should Contain "-RebootOk"
        }
        it "Restart file will have LocalRepoPath" {
            "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat" | should Contain "someRepo"
        }  
        remove-item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat"
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon"
    }

    Context "When no password is provided but reboot is ok" {
        Mock Check-Chocolatey
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Set-SecureAutoLogon
        Mock Restart
        Mock Call-Chocolatey
        $pass=ConvertTo-SecureString "mypassword" -asplaintext -force
        Mock Read-AuthenticatedPassword {return $pass}
        Mock Test-PendingReboot {return $true}
        Mock Get-UAC

        Invoke-Boxstarter test-package -RebootOk

        it "will read host for the password" {
            Assert-MockCalled Set-SecureAutoLogon -ParameterFilter {$password -eq $pass}
        }
        remove-item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat"
    }

    Context "When no password is provided, reboot is ok and autologon is toggled" {
        Mock Check-Chocolatey
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Set-SecureAutoLogon
        Mock Restart
        Mock Call-Chocolatey
        Mock Read-AuthenticatedPassword
        Mock Test-PendingReboot {return $true}
        Mock get-UAC
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value 1

        Invoke-Boxstarter test-package -RebootOk

        it "will not read host for the password" {
            Assert-MockCalled Read-AuthenticatedPassword -times 0
        }
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon"
        remove-item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat"
    }

    Context "When a password is provided and reboot is ok" {
        Mock Check-Chocolatey
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Set-SecureAutoLogon
        Mock Restart
        Mock Call-Chocolatey
        Mock Read-AuthenticatedPassword

        Invoke-Boxstarter test-package -RebootOk -password (ConvertTo-SecureString "mypassword" -asplaintext -force)

        it "will not read host for the password" {
            Assert-MockCalled Read-AuthenticatedPassword -times 0
        }
    }

    Context "When reboot is not ok" {
        Mock Check-Chocolatey
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Set-SecureAutoLogon
        Mock Restart
        Mock Call-Chocolatey
        Mock Read-AuthenticatedPassword
        Mock Test-PendingReboot {return $true}

        Invoke-Boxstarter test-package

        it "will not read host for the password" {
            Assert-MockCalled Read-AuthenticatedPassword -times 0
        }
        it "will not reboot" {
            Assert-MockCalled Restart -times 0
        }
    }

    Context "When ReEnableUAC is Set" {
        if(!(get-module Boxstarter.Helpers)){
            Import-Module $here\..\Helpers\Boxstarter.Helpers.psm1
        }
        Mock Check-Chocolatey
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Chocolatey
        Mock Enable-UAC

        Invoke-Boxstarter test-package -ReEnableUAC

        it "will Enable UAC" {
            Assert-MockCalled Enable-UAC
        }
    }

    Context "When ReEnableUAC is not Set" {
        if(!(get-module Boxstarter.Helpers)){
            Import-Module $here\..\Helpers\Boxstarter.Helpers.psm1
        }
        Mock Check-Chocolatey
        Mock Stop-Service
        Mock Start-Service
        Mock Set-Service
        Mock Chocolatey
        Mock Enable-UAC

        Invoke-Boxstarter test-package

        it "will Not Enable UAC" {
            Assert-MockCalled Enable-UAC -times 0
        }
    }
}