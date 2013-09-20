$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.chocolatey){Remove-Module boxstarter.chocolatey}

Resolve-Path $here\..\boxstarter.common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\boxstarter.winconfig\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\boxstarter.bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\boxstarter.chocolatey\*.ps1 | 
    % { . $_.ProviderPath }    
$Boxstarter.SuppressLogging=$true

Describe "Install-BoxstarterPackage" {
    Mock Invoke-ChocolateyBoxstarter
    Mock Enable-PSRemoting
    Mock Enable-WSManCredSSP
    Mock Disable-WSManCredSSP

    Context "When calling locally" {
        
        Install-BoxstarterPackage -PackageName test -DisableReboots -NoPassword -KeepWindowOpen

        It "will call InvokeChocolateyBoxstarter with parameters"{
            Assert-MockCalled Invoke-ChocolateyBoxstarter -ParameterFilter {$BootstrapPackage -eq "test" -and $DisableReboots -eq $True -and $NoPassword -eq $True -and $KeepWindowOpen -eq $True}
        }
    }

    Context "When calling locally with a credential and -nopassword" {
        $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)

        Install-BoxstarterPackage -PackageName test -DisableReboots -Credential $cred -NoPassword -KeepWindowOpen

        It "will nott InvokeChocolateyBoxstarter with password"{
            Assert-MockCalled Invoke-ChocolateyBoxstarter -ParameterFilter {$NoPassword -eq $True -and $Password -eq $null}
        }
    }

    Context "When calling locally with a credential" {
        $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)

        Install-BoxstarterPackage -PackageName test -DisableReboots -Credential $cred -KeepWindowOpen

        It "will call InvokeChocolateyBoxstarter with password"{
            Assert-MockCalled Invoke-ChocolateyBoxstarter -ParameterFilter {$Password -eq $cred.Password}
        }
    }

    Context "When Remoting is not enabled locally" {
        Mock Get-WSManCredSSP {throw "remoting not enabled"}
        Mock Confirm-Choice

        Install-BoxstarterPackage -computerName blah -PackageName test

        It "will confirm to enable remoting"{
            Assert-MockCalled Confirm-Choice -ParameterFilter {$message -like "*Remoting is not enabled locally*"}
        }
    }

    Context "When Remoting is not enabled locally" {
        Mock Get-WSManCredSSP {throw "remoting not enabled"}
        Mock Confirm-Choice {return $True}

        Install-BoxstarterPackage -computerName blah -PackageName test

        It "will enable remoting if user confirms"{
            Assert-MockCalled Enable-PSRemoting
        }
    }

    Context "When Remoting is not enabled locally" {
        Mock Get-WSManCredSSP {throw "remoting not enabled"}
        Mock Confirm-Choice {return $False}

        Install-BoxstarterPackage -computerName blah -PackageName test

        It "will not enable remoting if user does not confirm"{
            Assert-MockCalled Enable-PSRemoting -Times 0
        }
    }

    Context "When credssp is not enabled at all" {
        Mock Get-WSManCredSSP {return @("The machine is not","")}
        Mock Confirm-Choice {return $False}

        Install-BoxstarterPackage -computerName blah -PackageName test

        It "will enable for computer"{
            Assert-MockCalled Enable-WSManCredSSP -ParameterFilter {$DelegateComputer -eq "blah"}
        }
        It "will disable credssp when done"{
            Assert-MockCalled Disable-WSManCredSSP -ParameterFilter {$Role -eq "client"}
        }        
    }

    Context "When credssp is enabled but not for given computer" {
        Mock Get-WSManCredSSP {return @("The machine is enabled: wsman/blahblah","")}
        Mock Confirm-Choice {return $False}

        Install-BoxstarterPackage -computerName blah -PackageName test

        It "will enable for computer"{
            Assert-MockCalled Enable-WSManCredSSP -ParameterFilter {$DelegateComputer -eq "blah"}
        }
        It "will enable credssp when done for current computer"{
            Assert-MockCalled Enable-WSManCredSSP -ParameterFilter {$Role -eq "client" -and $DelegateComputer -eq "blahblah"}
        }
        It "will disable/reset when done"{
            Assert-MockCalled Disable-WSManCredSSP -ParameterFilter {$Role -eq "client"}
        }
    }    
}