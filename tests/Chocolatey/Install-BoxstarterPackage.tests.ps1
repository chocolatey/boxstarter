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

Describe "Install-BoxstarterPackage" {
    $regRoot="HKCU:\SOFTWARE\Pester\temp"
    Mock Get-CredentialDelegationKey { $regRoot }
    Mock Enable-RemotePSRemoting
    Mock Invoke-ChocolateyBoxstarter
    Mock Enable-PSRemoting
    Mock Enable-WSManCredSSP
    Mock Test-WSMan { return New-Object PSObject }
    Mock Disable-WSManCredSSP
    Mock Set-Item -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts"}
    Mock Invoke-WmiMethod { New-Object System.Object }
    Mock Setup-BoxstarterModuleAndLocalRepo -ParameterFilter{$session -eq $null}
    Mock Invoke-Remotely -ParameterFilter{$session -eq $null}
    Mock New-PSSession -ParameterFilter{$computerName -ne "localhost"}
    $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
    $mycreds = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)

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

        It "will not InvokeChocolateyBoxstarter with password"{
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

    Context "When credssp is not enabled at all" {
        Mock Get-WSManCredSSP {return @("The machine is not","")}
        Mock Confirm-Choice {return $False}
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah -PackageName test -Credential $mycreds

        It "will disable credssp when done"{
            Assert-MockCalled Disable-WSManCredSSP -ParameterFilter {$Role -eq "client"}
        }        
    }

    Context "When credssp is enabled but not for given computer" {
        Mock Get-WSManCredSSP {return @("The machine is enabled: wsman/blahblah","")}
        Mock Confirm-Choice {return $False}
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah -PackageName test -Credential $mycreds

        It "will enable credssp when done for current computer"{
            Assert-MockCalled Enable-WSManCredSSP -ParameterFilter {$Role -eq "client" -and $DelegateComputer -eq "blahblah"}
        }
        It "will disable/reset when done"{
            Assert-MockCalled Disable-WSManCredSSP -ParameterFilter {$Role -eq "client"}
        }
    }    

    Context "When credential delegation is not set for given computer" {
        New-Item $regRoot -Force | out-null
        Mock Get-WSManCredSSP {return @("The machine is enabled: wsman/blahblah","")}
        Mock Confirm-Choice {return $False}
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah -PackageName test -Credential $mycreds

        It "will remove computer when done"{
            (Get-Item -Path "$regRoot\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly").Property.Length | should be 0
        }
    }    

    Context "When no entries in trusted hosts" {
        Mock Get-Item {@{Value=""}} -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts"}
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah -PackageName test -Credential $mycreds

        It "will clear computer when done"{
            Assert-MockCalled Set-Item -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts" -and $Value -eq ""}
        }
    }

    Context "When entries in trusted hosts do not contain computer" {
        Mock Get-Item {@{Value="bler,blur,blor"}} -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts"}
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah -PackageName test -Credential $mycreds

        It "will clear computer when done"{
            Assert-MockCalled Set-Item -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts" -and $Value -eq "bler,blur,blor"}
        }
    }

    Context "When entries in trusted hosts contain computer" {
        Mock Get-Item {@{Value="bler,blah,blor"}} -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts"}
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah -PackageName test -Credential $mycreds

        It "will only set hosts once (at the end)"{
            Assert-MockCalled Set-Item -Times 1
        }
        It "will set to original when done"{
            Assert-MockCalled Set-Item -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts" -and $Value -eq "bler,blah,blor"}
        }
    }    

    Context "When remoting and wmi are not enabled on remote computer" {
        Mock Invoke-Command -ParameterFilter{$computerName -ne "localhost" -and ($Session -eq $null -or $Session.ComputerName -ne "localhost")}
        Mock Invoke-WmiMethod
        Mock Invoke-Command { New-Object System.Object }

        try {Install-BoxstarterPackage -computerName blah -PackageName test -Credential $mycreds} catch {$err=$_}

        It "will throw"{
            $err | should not be $null
        }
    }

    Context "When remoting not enabled on remote computer but WMI is and the force switch is not set" {
        Mock Invoke-Command -ParameterFilter{$computerName -ne "localhost" -and ($Session -eq $null -or $Session.ComputerName -ne "localhost")}
        Mock Confirm-Choice
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah -PackageName test -Credential $mycreds

        It "will Confirm ok to enable remoting"{
            Assert-MockCalled Confirm-Choice -ParameterFilter {$message -like "*Remoting is not enabled on Remote computer*"}
        }
    }

    Context "When remoting not enabled on remote computer but WMI is and the force switch is set" {
        Mock Invoke-Command -ParameterFilter{$computerName -ne "localhost" -and ($Session -eq $null -or $Session.ComputerName -ne "localhost")}
        Mock Confirm-Choice
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah -PackageName test -Credential $mycreds -Force

        It "will not Confirm ok to enable remoting"{
            Assert-MockCalled Confirm-Choice -Times 0
        }
        It "will run the cookbook script"{
            Assert-MockCalled Enable-RemotePSRemoting
        }
    }

    Context "When remoting enabled on remote and local computer and CredSSP is enabled on remote" {
        Mock Enable-RemotePSRemoting { return New-Object PSObject }
        Mock Test-WSMan { New-Object PSObject }
        Mock Invoke-Command

        Install-BoxstarterPackage -computerName blah -PackageName test -Credential $mycreds -Force

        It "will Enable CredSSP on Remote"{
            Assert-MockCalled Invoke-Command -ParameterFilter {$ScriptBlock.ToString() -like "*Invoke-FromTask `"Enable-WSManCredSSP -Role Server -Force | out-Null`"*"} -Times 0
        }
        It "will disable CredSSP when done"{
            Assert-MockCalled Invoke-Command -ParameterFilter {$ScriptBlock.ToString() -like "*Invoke-FromTask `"Disable-WSManCredSSP -Role Server | out-Null`"*"} -Times 0
        }        
    }

    Context "When remoting enabled on remote and local computer but CredSSP is not enabled on remote" {
        Mock Enable-RemotePSRemoting { return New-Object PSObject }
        Mock Test-WSMan
        Mock Invoke-Command

        Install-BoxstarterPackage -computerName blah -PackageName test -Credential $mycreds -Force

        It "will Enable CredSSP on Remote"{
            Assert-MockCalled Invoke-Command -ParameterFilter {$ScriptBlock.ToString() -like "*Invoke-FromTask `"Enable-WSManCredSSP -Role Server -Force | out-Null`"*"}
        }
        It "will disable CredSSP when done"{
            Assert-MockCalled Invoke-Command -ParameterFilter {$ScriptBlock.ToString() -like "*Invoke-FromTask `"Disable-WSManCredSSP -Role Server | out-Null`"*"}
        }        
    }

    Context "When remoting enabled on remote and local computer" {
        $session = New-PSSession localhost
        Remove-Item "$env:temp\Boxstarter" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host $env:username

        Install-BoxstarterPackage -session $session -PackageName test-package -DisableReboots
        Write-Host $env:username

        It "will copy boxstarter modules"{
            "$env:temp\boxstarter\boxstarter.chocolatey\boxstarter.chocolatey.psd1" | should exist
            "$env:temp\boxstarter\boxstarter.bootstrapper\boxstarter.bootstrapper.psd1" | should exist
            "$env:temp\boxstarter\boxstarter.winconfig\boxstarter.winconfig.psd1" | should exist
            "$env:temp\boxstarter\boxstarter.common\boxstarter.common.psd1" | should exist
        }
        It "will copy boxstarter build packages"{
            Get-ChildItem "$($Boxstarter.LocalRepo)\*.nupkg" | % {
                "$env:temp\boxstarter\buildpackages\$($_.Name)" | should exist
            }
        }
        It "will execute package"{
            Get-Content "$env:temp\testpackage.txt" | should be "test-package"
        }        
    }

    Context "When passing in a session" {
        $session = New-PSSession localhost
        Mock Enable-BoxstarterClientRemoting
        Mock Enable-RemotingOnRemote
        Mock Setup-BoxstarterModuleAndLocalRepo
        Mock Invoke-Remotely
        
        Install-BoxstarterPackage -session $session -PackageName test-package -DisableReboots

        It "will not try to enable local side remoting"{
            Assert-MockCalled Enable-BoxstarterClientRemoting -Times 0
        }
        It "will not try to enable remote side remoting"{
            Assert-MockCalled Enable-RemotingOnRemote -Times 0
        }
        It "will not reset session"{
            $session.State | should be "Opened"
        }        
    }
}