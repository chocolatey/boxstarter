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
    Mock Test-WSMan { return New-Object PSObject } -ParameterFilter { $Credential -ne $null }
    Mock Disable-WSManCredSSP
    Mock Set-Item -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts"}
    Mock Invoke-WmiMethod { New-Object System.Object }
    Mock Setup-BoxstarterModuleAndLocalRepo -ParameterFilter{$session.ComputerName -eq $null }
    Mock Invoke-Remotely -ParameterFilter{$session.ComputerName -eq $null}
    Mock New-PSSession {@{Availability="Available"}} -ParameterFilter{$ComputerName -ne "localhost" -and $computerName -ne $null -and $ComputerName -ne "." -and $ComputerName -ne "$env:COMPUTERNAME"}
    $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
    $mycreds = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)

    Context "When calling locally" {
        
        Install-BoxstarterPackage -PackageName test -DisableReboots -KeepWindowOpen -LocalRepo "myRepo"

        It "will call InvokeChocolateyBoxstarter with parameters"{
            Assert-MockCalled Invoke-ChocolateyBoxstarter -ParameterFilter {$BootstrapPackage -eq "test" -and $DisableReboots -eq $True -and $KeepWindowOpen -eq $True -and $LocalRepo -eq "myRepo"}
        }
    }

    Context "When calling locally with no credential" {
        $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)

        Install-BoxstarterPackage -PackageName test -DisableReboots -KeepWindowOpen

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

        Install-BoxstarterPackage -computerName blah,blah2 -PackageName test -Credential $mycreds

        It "will disable credssp when done"{
            Assert-MockCalled Disable-WSManCredSSP -ParameterFilter {$Role -eq "client"}
        }        
    }

    Context "When credssp is enabled but not for given computer" {
        Mock Get-WSManCredSSP {return @("The machine is enabled: wsman/blahblah","")}
        Mock Confirm-Choice {return $False}
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah,blah2 -PackageName test -Credential $mycreds

        It "will enable credssp when done for current computer"{
            Assert-MockCalled Enable-WSManCredSSP -ParameterFilter {$Role -eq "client" -and $DelegateComputer -eq "blahblah"}
        }
        It "will disable/reset when done"{
            Assert-MockCalled Disable-WSManCredSSP -ParameterFilter {$Role -eq "client"}
        }
    }    

    Context "When credssp is enabled for only one given computer" {
        Mock Get-WSManCredSSP {return @("The machine is enabled: wsman/blah2","")}
        Mock Confirm-Choice {return $False}
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah,blah2 -PackageName test -Credential $mycreds

        It "will enable credssp for unenabled computer"{
            Assert-MockCalled Enable-WSManCredSSP -ParameterFilter {$Role -eq "client" -and $DelegateComputer -eq "blah"}
        }
        It "will enable credssp when done for current computer"{
            Assert-MockCalled Enable-WSManCredSSP -ParameterFilter {$Role -eq "client" -and $DelegateComputer -eq "blah2"}
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

        Install-BoxstarterPackage -computerName blah,blah2 -PackageName test -Credential $mycreds

        It "will clear computer when done"{
            Assert-MockCalled Set-Item -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts" -and $Value -eq ""}
        }
    }

    Context "When entries in trusted hosts do not contain computer" {
        Mock Get-Item {@{Value="bler,blur,blor"}} -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts"}
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah,blah2 -PackageName test -Credential $mycreds

        It "will add computer"{
            Assert-MockCalled Set-Item -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts" -and $Value -eq "bler,blur,blor,blah,blah2"}
        }
        It "will clear computer when done"{
            Assert-MockCalled Set-Item -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts" -and $Value -eq "bler,blur,blor"}
        }
    }

    Context "When entries in trusted hosts contain only one computer" {
        Mock Get-Item {@{Value="bler,blah,blor"}} -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts"}
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah,blah2 -PackageName test -Credential $mycreds

        It "will add computer not in list"{
            Assert-MockCalled Set-Item -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts" -and $Value -eq "bler,blah,blor,blah2"}
        }
        It "will clear computer when done"{
            Assert-MockCalled Set-Item -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts" -and $Value -eq "bler,blah,blor"}
        }
    }

    Context "When entries in trusted hosts contain computer" {
        Mock Get-Item {@{Value="bler,blah,blor"}} -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts"}
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah,blor -PackageName test -Credential $mycreds

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
        Mock Test-WSMan -ParameterFilter { $Credential -ne $null }
        Mock Invoke-Command

        Install-BoxstarterPackage -computerName blah,blah2 -PackageName test -Credential $mycreds -Force

        It "will Enable CredSSP on Remote on both computers"{
            Assert-MockCalled Invoke-Command -ParameterFilter {$ScriptBlock.ToString() -like "*Invoke-FromTask `"Enable-WSManCredSSP -Role Server -Force | out-Null`"*"} -Times 2
        }
        It "will disable CredSSP when done on both computers"{
            Assert-MockCalled Invoke-Command -ParameterFilter {$ScriptBlock.ToString() -like "*Invoke-FromTask `"Disable-WSManCredSSP -Role Server | out-Null`"*"} -Times 2
        }        
    }

    Context "When using a session and remoting enabled on remote and local computer" {
        $session = New-PSSession localhost
        $session2 = New-PSSession .
        Remove-Item "$env:temp\Boxstarter" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:temp\testpackage.txt" -Force -ErrorAction SilentlyContinue

        Install-BoxstarterPackage -session $session,$session2 -PackageName test-package -DisableReboots

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
            ((Get-Content "$env:temp\testpackage.txt") -join ",") | should be "test-package,test-package"
        }
        Remove-PSSession $session
    }

    Context "When using a session and remoting enabled on remote and local computer and passing LocalRepo" {
        Mock Invoke-Remotely
        $repo=(Get-PSDrive TestDrive).Root
        Copy-Item "$($Boxstarter.LocalRepo)\example.*.nupkg" "$repo\mylocalrepo.nupkg"
        $session = New-PSSession localhost
        Remove-Item "$env:temp\Boxstarter" -Recurse -Force -ErrorAction SilentlyContinue
        $currentRepo=$Boxstarter.LocalRepo
    
        Install-BoxstarterPackage -session $session -PackageName test-package -DisableReboots -LocalRepo $repo

        It "will copy boxstarter build packages"{
            "$env:temp\boxstarter\buildpackages\mylocalrepo.nupkg" | should exist
        }
        Remove-PSSession $session
        $Boxstarter.LocalRepo=$currentRepo
    }

    Context "When using a computer name and remoting enabled on remote and local computer" {
        Mock Enable-RemotingOnRemote { return $true }
        Mock Enable-BoxstarterClientRemoting {@{Success=$true}}
        Remove-Item "$env:temp\Boxstarter" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:temp\testpackage.txt" -Force -ErrorAction SilentlyContinue

        Install-BoxstarterPackage -computerName localhost,$env:COMPUTERNAME -PackageName test-package -DisableReboots

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
            ((Get-Content "$env:temp\testpackage.txt") -join ",") | should be "test-package,test-package"
        }
    }

    Context "When using a connectionURI and remoting enabled on remote and local computer" {
        Mock Enable-RemotingOnRemote { return $true }
        Mock Enable-BoxstarterClientRemoting {@{Success=$true}}
        Remove-Item "$env:temp\Boxstarter" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:temp\testpackage.txt" -Force -ErrorAction SilentlyContinue

        Install-BoxstarterPackage -ConnectionURI "http://localhost:5985/wsman","http://$($env:computername):5985/wsman" -PackageName test-package -DisableReboots

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
            ((Get-Content "$env:temp\testpackage.txt") -join ",") | should be "test-package,test-package"
        }
    }

    Context "When passing in a session and no reboots" {
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
        Remove-PSSession $session
    }

    Context "When passing in a session that reboots" {
        $session = New-PSSession -ComputerName localhost -Name "testSession"
        Mock Enable-BoxstarterClientRemoting
        Mock Enable-RemotingOnRemote
        Mock Setup-BoxstarterModuleAndLocalRepo
        Mock Invoke-Command { return @{Result="Completed"} } -ParameterFilter {$ScriptBlock -ne $null -and $ScriptBlock.ToString() -like "*ChocolateyBoxstarter*"}
        Mock Invoke-Command { Remove-PSSession -Name "testSession" } -ParameterFilter {$ScriptBlock -ne $null -and $ScriptBlock.ToString() -like "*ChocolateyBoxstarter*" -and $Session.Name -eq "testSession" }
        Mock New-PSSession { return Microsoft.PowerShell.Core\New-PSSession localhost }

        Install-BoxstarterPackage -session $session -PackageName test-package -DisableReboots

        It "will not try to enable local side remoting"{
            Assert-MockCalled Enable-BoxstarterClientRemoting -Times 0
        }
        It "will not try to enable remote side remoting"{
            Assert-MockCalled Enable-RemotingOnRemote -Times 0
        }
        It "will reconnect with the correct uri"{
            Assert-MockCalled New-PSSession -ParameterFilter { $ConnectionURI -like "http://localhost:5985/wsman?PSVersion=*"}
        }
    }

    Context "When passing in a session that reboots and cant find port" {
        $session = New-PSSession -ComputerName localhost -Name "testSession"
        Mock Enable-BoxstarterClientRemoting
        Mock Enable-RemotingOnRemote
        Mock Test-WSMan
        Mock Setup-BoxstarterModuleAndLocalRepo
        Mock Invoke-Command { return @{Result="Completed"} } -ParameterFilter {$ScriptBlock -ne $null -and $ScriptBlock.ToString() -like "*ChocolateyBoxstarter*"}
        Mock Invoke-Command { Remove-PSSession -Name "testSession" } -ParameterFilter {$ScriptBlock -ne $null -and $ScriptBlock.ToString() -like "*ChocolateyBoxstarter*" -and $Session.Name -eq "testSession" }
        Mock Invoke-Command -ParameterFilter {$ScriptBlock -ne $null -and $ScriptBlock.ToString() -like "*PSSenderInfo*"}
        Mock New-PSSession { return Microsoft.PowerShell.Core\New-PSSession localhost }

        Install-BoxstarterPackage -session $session -PackageName test-package -DisableReboots

        It "will reconnect with the computer name"{
            Assert-MockCalled New-PSSession -ParameterFilter {$computerName -eq "localhost"}
        }
    }

    Context "When passing in an unavailable session" {
        $session = New-PSSession localhost
        Remove-PSSession $session

        try{
            Install-BoxstarterPackage -session $session -PackageName test-package -DisableReboots
        }
        catch{$err=$_}

        It "Should throw a validation error"{
            $err.CategoryInfo.Reason | should be "ArgumentException"
        }
    }
}