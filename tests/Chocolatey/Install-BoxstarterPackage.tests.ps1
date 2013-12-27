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
    Mock Test-WSMan { return ([Xml]"<response><node/></response>").response } -ParameterFilter { $Credential -ne $null }
    Mock Disable-WSManCredSSP
    Mock Set-Item -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts"}
    Mock Invoke-WmiMethod { New-Object System.Object }
    Mock Setup-BoxstarterModuleAndLocalRepo -ParameterFilter{$session.ComputerName -eq $null }
    Mock Invoke-Remotely -ParameterFilter{$session.ComputerName -eq $null}
    Mock New-PSSession {@{Availability="Available"}} -ParameterFilter{$ComputerName -ne "localhost" -and $computerName -ne $null -and $ComputerName -ne "." -and $ComputerName -ne "$env:COMPUTERNAME"}
    $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
    $mycreds = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)

    Context "When remoting and wmi are not enabled on remote computer" {
        Mock Invoke-Command -ParameterFilter{$computerName -ne "localhost" -and ($Session -eq $null -or $Session.ComputerName -ne "localhost")}
        Mock Invoke-WmiMethod
        Mock Invoke-Command { New-Object System.Object }

        $result = Install-BoxstarterPackage -computerName blah -PackageName test -Credential $mycreds 2> $Null

        It "will throw"{
            $result.Errors.Count | should be 1
        }
        It "will report failure in results" {
            $result.Completed | should be $false
        }
    }

    Context "When remoting enabled on remote and local computer and CredSSP is enabled on remote" {
        Mock Enable-RemotePSRemoting { return New-Object PSObject }
        Mock Test-WSMan { return ([Xml]"<response><node/></response>").response }
        Mock Invoke-Command

        Install-BoxstarterPackage -computerName blah -PackageName test -Credential $mycreds -Force | Out-Null

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
        Mock Invoke-RetriableScript #-ParameterFilter {$RetryScript -ne $null -and $RetryScript.ToString() -like "*WSManCredSSP*"}
        Mock Invoke-Command { return $false } -ParameterFilter {$ScriptBlock -ne $null -and $ScriptBlock.ToString() -like "*Test-PendingReboot"}

        Install-BoxstarterPackage -computerName blah,blah2 -PackageName test -Credential $mycreds -Force | Out-Null

        It "will Enable CredSSP on Remote on both computers"{
            Assert-MockCalled Invoke-RetriableScript -ParameterFilter {$RetryScript.ToString() -like "*Invoke-FromTask `"Enable-WSManCredSSP -Role Server -Force | out-Null`"*"} -Times 2
        }
        It "will disable CredSSP when done on both computers"{
            Assert-MockCalled Invoke-Command -ParameterFilter {$ScriptBlock.ToString() -like "*Invoke-FromTask `"Disable-WSManCredSSP -Role Server | out-Null`"*"} -Times 2
        }        
    }

    Context "When using a BoxstarterconnectionConfig and remoting enabled on remote and local computer" {
        Mock Enable-RemotingOnRemote { return $true }
        Mock Enable-BoxstarterClientRemoting {@{Success=$true}}
        Mock Enable-BoxstarterCredSSP {@{Success=$true}}
        Remove-Item "$env:temp\Boxstarter" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:temp\testpackage.txt" -Force -ErrorAction SilentlyContinue

        $result = (new-Object -TypeName BoxstarterconnectionConfig -ArgumentList localhost,$null) | Install-BoxstarterPackage -PackageName test-package -DisableReboots

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
            ((Get-Content "$env:temp\testpackage.txt") -join ",") | should be "test-package"
        }
        It "will output correct computers in results"{
            $result[0].ComputerName | should be "localhost"
        }
        It "will report success in results" {
            $result[0].Completed | should be $true
        }
    }

    Context "When calling locally" {

        $result = Install-BoxstarterPackage -PackageName test -DisableReboots -KeepWindowOpen -LocalRepo "myRepo"

        It "will call InvokeChocolateyBoxstarter with parameters"{
            Assert-MockCalled Invoke-ChocolateyBoxstarter -ParameterFilter {$BootstrapPackage -eq "test" -and $DisableReboots -eq $True -and $KeepWindowOpen -eq $True -and $LocalRepo -eq "myRepo"}
        }
        It "will output correct computers in results"{
            $result.ComputerName | should be "localhost"
        }
        It "will report success in results" {
            $result.Completed | should be $true
        }
    }

    Context "When calling locally with no credential" {
        $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)

        Install-BoxstarterPackage -PackageName test -DisableReboots -KeepWindowOpen | Out-Null

        It "will not InvokeChocolateyBoxstarter with password"{
            Assert-MockCalled Invoke-ChocolateyBoxstarter -ParameterFilter {$NoPassword -eq $True -and $Password -eq $null}
        }
    }

    Context "When calling locally with a credential" {
        $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)

        Install-BoxstarterPackage -PackageName test -DisableReboots -Credential $cred -KeepWindowOpen | Out-Null

        It "will call InvokeChocolateyBoxstarter with password"{
            Assert-MockCalled Invoke-ChocolateyBoxstarter -ParameterFilter {$Password -eq $cred.Password}
        }
    }

    Context "When credssp is not enabled at all" {
        Mock Get-WSManCredSSP {return @("The machine is not","")}
        Mock Confirm-Choice {return $False}
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah,blah2 -PackageName test -Credential $mycreds | Out-Null

        It "will disable credssp when done"{
            Assert-MockCalled Disable-WSManCredSSP -ParameterFilter {$Role -eq "client"}
        }        
    }

    Context "When credssp is enabled but not for given computer" {
        Mock Get-WSManCredSSP {return @("The machine is enabled: wsman/blahblah","")}
        Mock Confirm-Choice {return $False}
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah,blah2 -PackageName test -Credential $mycreds | Out-Null

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

        Install-BoxstarterPackage -computerName blah,blah2 -PackageName test -Credential $mycreds | Out-Null

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

        Install-BoxstarterPackage -computerName blah -PackageName test -Credential $mycreds | Out-Null

        It "will remove computer when done"{
            (Get-Item -Path "$regRoot\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly").Property.Length | should be 0
        }
    }    

    Context "When no entries in trusted hosts" {
        Mock Get-Item {@{Value=""}} -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts"}
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah,blah2 -PackageName test -Credential $mycreds | Out-Null

        It "will clear computer when done"{
            Assert-MockCalled Set-Item -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts" -and $Value -eq ""}
        }
    }

    Context "When entries in trusted hosts do not contain computer" {
        Mock Get-Item {@{Value="bler,blur,blor"}} -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts"}
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah,blah2 -PackageName test -Credential $mycreds | Out-Null

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

        Install-BoxstarterPackage -computerName blah,blah2 -PackageName test -Credential $mycreds | Out-Null

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

        Install-BoxstarterPackage -computerName blah,blor -PackageName test -Credential $mycreds | Out-Null

        It "will only set hosts once (at the end)"{
            Assert-MockCalled Set-Item -Times 1
        }
        It "will set to original when done"{
            Assert-MockCalled Set-Item -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts" -and $Value -eq "bler,blah,blor"}
        }
    }    

    Context "When entries in trusted hosts contain global wildcard" {
        Mock Get-Item {@{Value="*"}} -ParameterFilter {$Path -eq "wsman:\localhost\client\trustedhosts"}
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah,blor -PackageName test -Credential $mycreds | Out-Null

        It "will not set hosts"{
            Assert-MockCalled Set-Item -Times 0
        }
    }    

    Context "When remoting not enabled on remote computer but WMI is and the force switch is not set" {
        Mock Invoke-Command -ParameterFilter{$computerName -ne "localhost" -and ($Session -eq $null -or $Session.ComputerName -ne "localhost")}
        Mock Confirm-Choice
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah -PackageName test -Credential $mycreds 2>&1 | Out-Null

        It "will Confirm ok to enable remoting"{
            Assert-MockCalled Confirm-Choice -ParameterFilter {$message -like "*Remoting is not enabled on Remote computer*"}
        }
    }

    Context "When remoting not enabled on remote computer but WMI is and the force switch is set" {
        Mock Invoke-Command -ParameterFilter{$computerName -ne "localhost" -and ($Session -eq $null -or $Session.ComputerName -ne "localhost")}
        Mock Confirm-Choice
        Mock Invoke-Command { New-Object System.Object }

        Install-BoxstarterPackage -computerName blah -PackageName test -Credential $mycreds -Force | Out-Null

        It "will not Confirm ok to enable remoting"{
            Assert-MockCalled Confirm-Choice -Times 0
        }
        It "will run the cookbook script"{
            Assert-MockCalled Enable-RemotePSRemoting
        }
    }

    Context "When using a https ConnectionURI and testing CredSSP" {
        Mock Enable-RemotePSRemoting { return New-Object PSObject }
        Mock Test-WSMan -ParameterFilter { $Credential -ne $null }
        Mock Invoke-Command
        Mock New-PSSession {@{Availability="Available"}}

        Install-BoxstarterPackage -ConnectionURI "https://server:5678/wsman" -PackageName test -Credential $mycreds -Force | Out-Null

        It "will use https"{
            Assert-MockCalled Test-WSMan -ParameterFilter {$UseSSL -eq $true}
        }
        It "will specify port"{
            Assert-MockCalled Test-WSMan -ParameterFilter {$Port -eq 5678}
        }        
    }

    Context "When using a http ConnectionURI and testing CredSSP" {
        Mock Enable-RemotePSRemoting { return New-Object PSObject }
        Mock Test-WSMan -ParameterFilter { $Credential -ne $null }
        Mock Invoke-Command
        Mock New-PSSession {@{Availability="Available"}}

        [uri]"http://server:5678/wsman" | Install-BoxstarterPackage -PackageName test -Credential $mycreds -Force | Out-Null

        It "will use http"{
            Assert-MockCalled Test-WSMan -ParameterFilter {$UseSSL -eq $false}
        }
        It "will specify port"{
            Assert-MockCalled Test-WSMan -ParameterFilter {$Port -eq 5678}
        }        
    }

    Context "When using a session and remoting enabled on remote and local computer" {
        $session = New-PSSession localhost
        $session2 = New-PSSession .
        Remove-Item "$env:temp\Boxstarter" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:temp\testpackage.txt" -Force -ErrorAction SilentlyContinue

        $result = ($session,$session2) | Install-BoxstarterPackage -PackageName test-package -DisableReboots

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
        It "will output correct computers in results"{
            $result[0].ComputerName | should be "localhost"
            $result[1].ComputerName | should be "localhost"
        }
        It "will report success in results" {
            $result[0].Completed | should be $true
            $result[1].Completed | should be $true
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
    
        Install-BoxstarterPackage -session $session -PackageName test-package -DisableReboots -LocalRepo $repo | Out-Null

        It "will copy boxstarter build packages"{
            "$env:temp\boxstarter\buildpackages\mylocalrepo.nupkg" | should exist
        }
        Remove-PSSession $session
        $Boxstarter.LocalRepo=$currentRepo
    }

    Context "When using a boxstarter.config with a custom LocalRepo" {
        Mock Invoke-Remotely
        $repo=(Get-PSDrive TestDrive).Root
        Copy-Item "$($Boxstarter.LocalRepo)\example.*.nupkg" "$repo\mylocalrepo.nupkg"
        $session = New-PSSession localhost
        Remove-Item "$env:temp\Boxstarter" -Recurse -Force -ErrorAction SilentlyContinue
        $currentConfig=Get-Content "$($Boxstarter.BaseDir)\Boxstarter.Config"
        $currentRepo=$Boxstarter.LocalRepo
        Set-BoxStarterConfig -LocalRepo $repo
    
        Install-BoxstarterPackage -session $session -PackageName test-package -DisableReboots -LocalRepo $repo | Out-Null

        It "will Remove LocalRepo node in Boxstarter.Config on Remote"{
            [xml]$configXml = Get-Content "$env:temp\boxstarter\boxstarter.config"
            $configXml.config.LocalRepo | should be $null
        }
        Remove-PSSession $session
        $Boxstarter.LocalRepo=$currentRepo
        Set-Content "$($Boxstarter.BaseDir)\Boxstarter.Config" -Value $currentConfig -Force
    }

    Context "When using a computer name and remoting enabled on remote and local computer" {
        Mock Enable-RemotingOnRemote { return $true }
        Mock Enable-BoxstarterClientRemoting {@{Success=$true}}
        Mock Enable-BoxstarterCredSSP {@{Success=$true}}

        Remove-Item "$env:temp\Boxstarter" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:temp\testpackage.txt" -Force -ErrorAction SilentlyContinue

        $result = ("localhost",$env:COMPUTERNAME) | Install-BoxstarterPackage -PackageName test-package -DisableReboots

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
        It "will output 2 results"{
            $result.Count | Should be 2
        }
        It "will output correct computers in results"{
            $result[0].ComputerName | should be "localhost"
            $result[1].ComputerName | should be $env:COMPUTERNAME
        }
        It "will report success in results" {
            $result[0].Completed | should be $true
            $result[1].Completed | should be $true
        }
    }

    Context "When installing a package that throws an error" {
        Mock Enable-RemotingOnRemote { return $true }
        Mock Enable-BoxstarterClientRemoting {@{Success=$true}}
        Mock Enable-BoxstarterCredSSP {@{Success=$true}}
        Remove-Item "$env:temp\Boxstarter" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:temp\testpackage.txt" -Force -ErrorAction SilentlyContinue

        $result = Install-BoxstarterPackage -computerName localhost -PackageName exception-package -DisableReboots 2> $null

        It "will include exceptions"{
            $result.Errors.Count | should be 2
        }
        It "will report success in results" {
            $result.Completed | should be $true
        }
    }

    Context "When using a connectionURI and remoting enabled on remote and local computer" {
        Mock Enable-RemotingOnRemote { return $true }
        Mock Enable-BoxstarterClientRemoting {@{Success=$true}}
        Mock Enable-BoxstarterCredSSP {@{Success=$true}}
        Remove-Item "$env:temp\Boxstarter" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:temp\testpackage.txt" -Force -ErrorAction SilentlyContinue

        $result = ([URI]"http://localhost:5985/wsman",[URI]"http://$($env:computername):5985/wsman") | Install-BoxstarterPackage -PackageName test-package -DisableReboots

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
        It "will output correct computers in results"{
            $result[0].ComputerName | should be "localhost"
            $result[1].ComputerName | should be $env:COMPUTERNAME
        }
        It "will report success in results" {
            $result[0].Completed | should be $true
            $result[1].Completed | should be $true
        }
    }

    Context "When passing in a session and no reboots" {
        $session = New-PSSession localhost
        Mock Enable-BoxstarterClientRemoting
        Mock Enable-BoxstarterCredSSP
        Mock Enable-RemotingOnRemote
        Mock Setup-BoxstarterModuleAndLocalRepo
        Mock Invoke-Remotely

        Install-BoxstarterPackage -session $session -PackageName test-package -DisableReboots | Out-Null

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
        Mock Enable-BoxstarterCredSSP
        Mock Enable-RemotingOnRemote
        Mock Setup-BoxstarterModuleAndLocalRepo
        Mock Invoke-Command { return @{Result="Completed"} } -ParameterFilter {$ScriptBlock -ne $null -and $ScriptBlock.ToString() -like "*ChocolateyBoxstarter*"}
        Mock Invoke-Command { Remove-PSSession -Name "testSession" } -ParameterFilter {$ScriptBlock -ne $null -and $ScriptBlock.ToString() -like "*ChocolateyBoxstarter*" -and $Session.Name -eq "testSession" }
        Mock New-PSSession { return Microsoft.PowerShell.Core\New-PSSession localhost }

        Install-BoxstarterPackage -session $session -PackageName test-package -DisableReboots | Out-Null

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
        Mock Enable-BoxstarterCredSSP
        Mock Enable-RemotingOnRemote
        Mock Test-WSMan
        Mock Setup-BoxstarterModuleAndLocalRepo
        Mock Invoke-Command { return @{Result="Completed"} } -ParameterFilter {$ScriptBlock -ne $null -and $ScriptBlock.ToString() -like "*ChocolateyBoxstarter*"}
        Mock Invoke-Command { Remove-PSSession -Name "testSession" } -ParameterFilter {$ScriptBlock -ne $null -and $ScriptBlock.ToString() -like "*ChocolateyBoxstarter*" -and $Session.Name -eq "testSession" }
        Mock Invoke-Command -ParameterFilter {$ScriptBlock -ne $null -and $ScriptBlock.ToString() -like "*PSSenderInfo*"}
        Mock New-PSSession { return Microsoft.PowerShell.Core\New-PSSession localhost }

        Install-BoxstarterPackage -session $session -PackageName test-package -DisableReboots | Out-Null

        It "will reconnect with the computer name"{
            Assert-MockCalled New-PSSession -ParameterFilter {$computerName -eq "localhost"}
        }
    }

    Context "When passing in an unavailable session" {
        $session = New-PSSession localhost
        Remove-PSSession $session

        $result = Install-BoxstarterPackage -session $session -PackageName test-package -DisableReboots 2> $null

        It "Should throw a validation error"{
            $result.Errors[0].Exception.Message | should match "The Session is not Available"
        }
        It "will report failure in results" {
            $result.Completed | should be $false
        }
    }
}