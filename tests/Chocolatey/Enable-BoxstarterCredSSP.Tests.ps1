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

Describe "Enable-BoxstarterCredSSP" {
    New-Item "HKCU:\SOFTWARE\Pester\temp" -Force | out-null
    $regRoot="HKCU:\SOFTWARE\Pester\temp"
    Mock Get-CredentialDelegationKey { $regRoot }
    Mock Enable-WSManCredSSP
    Mock Disable-WSManCredSSP

    Context "When CredSSP is not enabled at all" {
        Mock Get-WSManCredSSP {return @("The machine is not","")}
        Mock Confirm-Choice {return $False}

        Enable-BoxstarterCredSSP -RemoteHostsToTrust blah | out-null

        It "will enable for computer"{
            Assert-MockCalled Enable-WSManCredSSP -ParameterFilter {$DelegateComputer -eq "blah"}
        }
    }

    Context "When CredSSP is enabled but not for given computer" {
        Mock Get-WSManCredSSP {return @("The machine is enabled: wsman/blahblah","")}
        Mock Confirm-Choice {return $False}

        Enable-BoxstarterCredSSP -RemoteHostsToTrust blah | out-null

        It "will enable for computer"{
            Assert-MockCalled Enable-WSManCredSSP -ParameterFilter {$DelegateComputer -eq "blah"}
        }
    }

    Context "When credential delegation is not set for given computer" {
        New-Item $regRoot -Force | out-null
        Mock Get-WSManCredSSP {return @("The machine is enabled: wsman/blahblah","")}
        Mock Confirm-Choice {return $False}

        Enable-BoxstarterCredSSP -RemoteHostsToTrust blah | out-null

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

        Enable-BoxstarterCredSSP -RemoteHostsToTrust blah | out-null

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

        Enable-BoxstarterCredSSP -RemoteHostsToTrust blah | out-null

        It "will keep computer in list"{
            (Get-ItemProperty -Path "$regRoot\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly" -Name 1).1 | should be "wsman/blah"
        }
        It "will keep computer in list"{
            (Get-Item -Path "$regRoot\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly").Property.Length | should be 1

        }
    }
}
