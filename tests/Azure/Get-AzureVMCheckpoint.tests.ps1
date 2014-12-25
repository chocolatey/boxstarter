$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Remove-Module boxstarter.*
Resolve-Path $here\..\..\Boxstarter.Azure\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Chocolatey\*.ps1 | 
    % { . $_.ProviderPath }
Remove-Item alias:\Enable-BoxstarterVM
if(${env:ProgramFiles(x86)} -ne $null){ $programFiles86 = ${env:ProgramFiles(x86)} } else { $programFiles86 = $env:ProgramFiles }
$modulePath="$programFiles86\Microsoft SDKs\Windows Azure\PowerShell\Azure\Azure.psd1"
if(Test-Path $modulePath) {
    Import-Module $modulePath -global
}
Add-Type -Path "$env:ProgramW6432\Microsoft SDKs\Windows Azure\.NET SDK\v2.2\bin\plugins\caching\Microsoft.WindowsAzure.StorageClient.dll"

Describe "Get-AzureVMCheckpoint" {
    $Boxstarter.SuppressLogging=$true
    Mock Get-Blob

    Context "when not specifying a checkpoint and multiple VMs in cloud service" {
        $vm = new-Object Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVMRoleContext
        $vm.Name="myName"
        $vm.ServiceName="ServiceName"
        Mock Query-BlobSnapshots {
            @{ Metadata = @{ name="ServiceName-myName-checkpoint1" };SnapshotTime = [DateTime]::Now }
            @{ Metadata = @{ name="ServiceName-otherName-checkpoint1" };SnapshotTime = [DateTime]::Now }
            @{ Metadata = @{ name="ServiceName-myName-checkpoint2" };SnapshotTime = [DateTime]::Now }
        }

        $result = Get-AzureVMCheckpoint $vm

        It "should return 2 results" {
            $result.Count | should be 2
        }
        It "First result should be Checkpoint1" {
            $result[0].Name | should be "checkpoint1"
        }
        It "Second result should be Checkpoint2" {
            $result[1].Name | should be "checkpoint2"
        }
    }
}