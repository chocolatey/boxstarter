$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.Azure){Remove-Module boxstarter.Azure}
Resolve-Path $here\..\..\Boxstarter.Azure\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\..\Boxstarter.Chocolatey\*.ps1 | 
    % { . $_.ProviderPath }

Describe "Remove-AzureVMCheckpoint" {
    Add-Type -path "$env:ProgramFiles\Microsoft SDKs\Windows Azure\.NET SDK\v2.2\bin\Microsoft.WindowsAzure.StorageClient.dll"
    $Boxstarter.SuppressLogging=$false
    Mock Get-AzureOSDisk
    $vm = new-Object Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVMRoleContext
    $vm.Name="VMName"
    $vm.ServiceName="service"

}