$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Remove-Module boxstarter.*
Resolve-Path $here\..\..\Boxstarter.Common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Chocolatey\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Azure\*.ps1 | 
    % { . $_.ProviderPath }

Remove-Item alias:\Enable-BoxstarterVM

Describe "Enable-BoxstarterVM.Azure" {
    $Boxstarter.SuppressLogging=$true
    [Uri]$mediaLink="http://storage.net/smoe/path"
    Mock Get-AzureOSDisk {@{MediaLink=$mediaLink}}
    $vmName="VMName"
    $vmServiceName="service"
    [Uri]$vmConnectionURI="http://localhost:5985/wsman"
    $vm = new-Object Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVMRoleContext
    $vm.Name=$vmName
    $vm.ServiceName=$vmServiceName
    $vm.InstanceStatus="ReadyRole"
    Mock Get-AzureVM { return $vm }
    Mock Get-AzureVMCheckpoint
    Mock Install-WinRMCert
    Mock Get-AzureWinRMUri {return $vmConnectionURI}
    Mock Enable-BoxstarterClientRemoting
    Mock Set-AzureVMCheckpoint
    Mock Restore-AzureVMCheckpoint
    Mock get-AzureSubscription { return @{CurrentStorageAccountName="sa"} }
    Mock Invoke-RetriableScript -ParameterFilter {$RetryScript -ne $null -and $RetryScript.ToString() -like "*Get-WMIObject*"}
    Mock Set-AzureSubscription
    Mock Restart-computer
    $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
    $mycreds = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)

    Context "When a checkpoint is specified that exists"{
        $snapshotName="snapshot"
        Mock Get-AzureVMCheckpoint { "I am a snapshot" } -parameterFilter {$CheckpointName -eq $snapshotName}

        Enable-BoxstarterVM -VMName $vmName -CloudServiceName $vmServiceName -Credential $mycreds -CheckPointName $snapshotName -ErrorAction SilentlyContinue | Out-Null

        It "Should restore snapshot"{
            Assert-MockCalled Restore-AzureVMCheckpoint
        }
    }

    Context "When VM is not running"{
        $vm.InstanceStatus="Stopped"
        Mock Wait-ReadyState
        Mock Start-AzureVM -verifiable

        Enable-BoxstarterVM -VMName $vmName -CloudServiceName $vmServiceName -Credential $mycreds -ErrorAction SilentlyContinue | Out-Null

        It "Should start vm"{
            Assert-VerifiableMocks
        }
        $vm.InstanceStatus="ReadyRole"
    }

    Context "When a checkpoint is specified that does not exists"{
        $snapshotName="snapshot"

        Enable-BoxstarterVM -VMName $vmName -CloudServiceName $vmServiceName -Credential $mycreds -CheckPointName $snapshotName -ErrorAction SilentlyContinue | Out-Null

        It "Should not restore snapshot"{
            Assert-MockCalled Restore-AzureVMCheckpoint -times 0
        }
        It "Should create snapshot"{
            Assert-MockCalled Set-AzureVMCheckpoint -parameterFilter {$CheckPointName -eq $snapshotName -and $VM -eq $vm }
        }
    }

    Context "When no checkpoint is specified"{

        Enable-BoxstarterVM -VMName $vmName -CloudServiceName $vmServiceName -Credential $mycreds -ErrorAction SilentlyContinue | Out-Null

        It "Should not restore snapshot"{
            Assert-MockCalled Restore-AzureVMCheckpoint -times 0
        }
        It "Should not create snapshot"{
            Assert-MockCalled Set-AzureVMCheckpoint -times 0
        }
    }

    Context "When calling normally"{
        $result = Enable-BoxstarterVM -VMName $vmName -CloudServiceName $vmServiceName -Credential $mycreds -ErrorAction SilentlyContinue

        It "should return VM ConnectionURI" {
            $result.ConnectionURI | should be $vmConnectionURI
        }
        It "should return Credential" {
            $result.Credential | should be $mycreds
        }
    }

    Context "When Subscription Information has not been set"{
        Mock Get-AzureSubscription

        try {
            Enable-BoxstarterVM -VMName $vmName -CloudServiceName $vmServiceName -Credential $mycreds
        }
        catch {
            $err=$_
        }

        It "should throw instructions" {
            $err -ne $null
        }
    }

    Context "When CurrentStorageAccountName has not been set"{
        Mock Get-AzureSubscription {@{ 
            SubscriptionName="subName"
            CurrentStorageAccountName=$null 
        }}
        Mock Get-AzureStorageAccount {@(
            @{
                Label="acct1"
                Endpoints=@("https://acct1.net/","https://acct1.org/")
            },
            @{
                Label="acct2"
                Endpoints=@("https://storage.net/","https://storage.org/")
            }
        )}

        $result = Enable-BoxstarterVM -VMName $vmName -CloudServiceName $vmServiceName -Credential $mycreds -ErrorAction SilentlyContinue

        It "should set current storage account to acct2" {
            Assert-MockCalled Set-AzureSubscription -parameterFilter { $SubscriptionName -eq "subName" -and $CurrentStorageAccountName -eq "acct2" }
        }
    }

    Context "When VM cant be found"{
        Mock Get-AzureVM

        try {
            Enable-BoxstarterVM -VMName $vmName -CloudServiceName $vmServiceName -Credential $mycreds
        }
        catch {
            $err=$_
        }

        It "should throw InvalidOperationException" {
            $err.CategoryInfo.Reason | should be "InvalidOperationException"
        }
    }

    Context "When VM connectionURI cant be obtained"{
        Mock Get-AzureWinRMUri

        try {
            Enable-BoxstarterVM -VMName $vmName -CloudServiceName $vmServiceName -Credential $mycreds
        }
        catch {
            $err=$_
        }

        It "should throw InvalidOperationException" {
            $err.CategoryInfo.Reason | should be "InvalidOperationException"
        }
    }

    Context "When not running as admin"{
        Mock Test-Admin

        $result = Enable-BoxstarterVM -VMName $vmName -CloudServiceName $vmServiceName -Credential $mycreds -ErrorAction SilentlyContinue

        It "should not install certs" {
            Assert-MockCalled Install-WinRMCert -times 0
        }
        It "should skip CA Check" {
            $result.PSSessionOption.SkipCACheck | should be $true
        }
        It "should skip CN Check" {
            $result.PSSessionOption.SkipCNCheck | should be $true
        }
    }

    Context "When running as admin"{
        Mock Test-Admin {$true}

        $result = Enable-BoxstarterVM -VMName $vmName -CloudServiceName $vmServiceName -Credential $mycreds -ErrorAction SilentlyContinue

        It "should not install certs" {
            Assert-MockCalled Install-WinRMCert -times 1
        }
        It "should not skip CA Check" {
            $result.PSSessionOption.SkipCACheck | should be $false
        }
        It "should not skip CN Check" {
            $result.PSSessionOption.SkipCNCheck | should be $false
        }
    }
}