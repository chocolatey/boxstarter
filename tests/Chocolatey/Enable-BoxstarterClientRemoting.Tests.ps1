$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.chocolatey){Remove-Module boxstarter.chocolatey}

Resolve-Path $here\..\..\boxstarter.common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\boxstarter.winconfig\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\boxstarter.bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\boxstarter.chocolatey\*.ps1 | 
    % { . $_.ProviderPath }
$Boxstarter.SuppressLogging=$true

Describe "Enable-BoxstarterClientRemoting" {
    $regRoot="HKCU:\SOFTWARE\Pester\temp"
    Mock Get-CredentialDelegationKey { $regRoot }
    Mock Enable-PSRemoting
    Mock Enable-WSManCredSSP
    Mock Disable-WSManCredSSP
    Mock Set-Item -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts"}
    Mock Confirm-Choice

    Context "When Remoting is not enabled locally" {
        Mock Get-WSManCredSSP {throw "remoting not enabled"}

        Enable-BoxstarterClientRemoting -RemoteHostsToTrust blah | out-null

        It "will confirm to enable remoting"{
            Assert-MockCalled Confirm-Choice -ParameterFilter {$message -like "*Remoting is not enabled locally*"}
        }
    }

    Context "When Remoting is not enabled locally and user confirms" {
        Mock Get-WSManCredSSP {throw "remoting not enabled"}
        Mock Confirm-Choice {return $True}

        Enable-BoxstarterClientRemoting -RemoteHostsToTrust blah | out-null

        It "will enable remoting"{
            Assert-MockCalled Enable-PSRemoting
        }
    }

    Context "When Remoting is not enabled locally" {
        Mock Get-WSManCredSSP {throw "remoting not enabled"}
        Mock Confirm-Choice {return $False}

        Enable-BoxstarterClientRemoting -RemoteHostsToTrust blah | out-null

        It "will not enable remoting if user does not confirm"{
            Assert-MockCalled Enable-PSRemoting -Times 0
        }
    }

    Context "When credssp is not enabled at all" {
        Mock Get-WSManCredSSP {return @("The machine is not","")}
        Mock Confirm-Choice {return $False}

        Enable-BoxstarterClientRemoting -RemoteHostsToTrust blah | out-null

        It "will enable for computer"{
            Assert-MockCalled Enable-WSManCredSSP -ParameterFilter {$DelegateComputer -eq "blah"}
        }
    }

    Context "When credssp is enabled but not for given computer" {
        Mock Get-WSManCredSSP {return @("The machine is enabled: wsman/blahblah","")}
        Mock Confirm-Choice {return $False}

        Enable-BoxstarterClientRemoting -RemoteHostsToTrust blah | out-null

        It "will enable for computer"{
            Assert-MockCalled Enable-WSManCredSSP -ParameterFilter {$DelegateComputer -eq "blah"}
        }
    }    

    Context "When credential delegation is not set for given computer" {
        New-Item $regRoot -Force | out-null
        Mock Get-WSManCredSSP {return @("The machine is enabled: wsman/blahblah","")}
        Mock Confirm-Choice {return $False}

        Enable-BoxstarterClientRemoting -RemoteHostsToTrust blah | out-null

        It "will enable Allow Settings"{
            (Get-ItemProperty -Path "$regRoot\CredentialsDelegation" -Name AllowFreshCredentialsWhenNTLMOnly).AllowFreshCredentialsWhenNTLMOnly | should be 1
        }
        It "will add computer to list"{
            (Get-ItemProperty -Path "$regRoot\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly" -Name 1).1 | should be "wsman/blah"
        }
    }    

    Context "When credential delegation is not set for given computer and but it is set for other computers" {
        New-Item $regRoot -Force | out-null
        New-Item $regRoot -Name CredentialsDelegation | out-null
        New-ItemProperty -Path "$regRoot\CredentialsDelegation" -Name AllowFreshCredentialsWhenNTLMOnly -Value 1 -PropertyType Dword -Force | out-null
        New-Item "$regRoot\CredentialsDelegation" -Name AllowFreshCredentialsWhenNTLMOnly | out-null
        New-ItemProperty -Path "$regRoot\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly" -Name 1 -Value "wsman/other" -PropertyType String -Force | out-null
        Mock Get-WSManCredSSP {return @("The machine is enabled: wsman/blahblah","")}
        Mock Confirm-Choice {return $False}

        Enable-BoxstarterClientRemoting -RemoteHostsToTrust blah | out-null

        It "will add computer to list"{
            (Get-ItemProperty -Path "$regRoot\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly" -Name 2).2 | should be "wsman/blah"
        }
    }    

    Context "When credential delegation is already set for given computer" {
        New-Item $regRoot -Force | out-null
        New-Item $regRoot -Name CredentialsDelegation | out-null
        New-ItemProperty -Path "$regRoot\CredentialsDelegation" -Name AllowFreshCredentialsWhenNTLMOnly -Value 1 -PropertyType Dword -Force | out-null
        New-Item "$regRoot\CredentialsDelegation" -Name AllowFreshCredentialsWhenNTLMOnly | out-null
        New-ItemProperty -Path "$regRoot\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly" -Name 1 -Value "wsman/blah" -PropertyType String -Force | out-null
        Mock Get-WSManCredSSP {return @("The machine is enabled: wsman/blahblah","")}
        Mock Confirm-Choice {return $False}

        Enable-BoxstarterClientRemoting -RemoteHostsToTrust blah | out-null

        It "will keep computer in list"{
            (Get-ItemProperty -Path "$regRoot\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly" -Name 1).1 | should be "wsman/blah"
        }
        It "will keep computer in list"{
            (Get-Item -Path "$regRoot\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly").Property.Length | should be 1

        }
    }    

    Context "When no entries in trusted hosts" {
        Mock Get-Item {@{Value=""}} -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts"}

        Enable-BoxstarterClientRemoting -RemoteHostsToTrust blah | out-null

        It "will enable for computer"{
            Assert-MockCalled Set-Item -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts" -and $Value -eq "blah"}
        }
    }

    Context "When entries in trusted hosts do not contain computer" {
        Mock Get-Item {@{Value="bler,blur,blor"}} -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts"}

        Enable-BoxstarterClientRemoting -RemoteHostsToTrust blah | out-null

        It "will enable for computer"{
            Assert-MockCalled Set-Item -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts" -and $Value -eq "bler,blur,blor,blah"}
        }
    }
}