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
    Mock Enable-PSRemoting
    Mock Set-Item -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts"}
    Mock Confirm-Choice

    Context "When Remoting is not enabled locally" {
        Mock Test-WSMan {throw "remoting not enabled"}

        Enable-BoxstarterClientRemoting -RemoteHostsToTrust blah | out-null

        It "will confirm to enable remoting"{
            Assert-MockCalled Confirm-Choice -ParameterFilter {$message -like "*Remoting is not enabled locally*"}
        }
    }

    Context "When Remoting is not enabled locally and user confirms" {
        Mock Test-WSMan {throw "remoting not enabled"}
        Mock Confirm-Choice {return $True}

        Enable-BoxstarterClientRemoting -RemoteHostsToTrust blah | out-null

        It "will enable remoting"{
            Assert-MockCalled Enable-PSRemoting
        }
    }

    Context "When Remoting is not enabled locally" {
        Mock Test-WSMan {throw "remoting not enabled"}
        Mock Confirm-Choice {return $False}

        Enable-BoxstarterClientRemoting -RemoteHostsToTrust blah | out-null

        It "will not enable remoting if user does not confirm"{
            Assert-MockCalled Enable-PSRemoting -Times 0
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