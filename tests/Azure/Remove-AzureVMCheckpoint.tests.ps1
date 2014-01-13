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
    $Boxstarter.SuppressLogging=$false
    Mock Get-AzureVM { 
        $obj=New-Object -TypeName Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVMRoleListContext
        $obj.ServiceName="myService"
        $obj.Status="ReadyRole"
        return $obj 
    } -parameterFilter {$ServiceName.Length -eq 0}
    Mock Get-AzureVM { 
        return New-Object -TypeName Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVM
    } -parameterFilter {$ServiceName.Length -gt 0}
    Mock Get-AzureOSDisk

    Context "When Azure .NET SDK is not installed" {
        Mock Add-Type { throw "not installed" }

        try {
            Remove-AzureVMCheckpoint -VMName "vm" -CheckpointName "cp"
        }
        catch{
            $err = $_
        }

        It "Will throw Invalid Operation Exception" {
            $err.CategoryInfo.Reason | should be "InvalidOperationException"
        }
    }

    Context "When VM cannot be found" {
        Mock Get-AzureVM { return $null } -parameterFilter {$ServiceName.Length -eq 0}

        try {
            Remove-AzureVMCheckpoint -VMName "vm" -CheckpointName "cp"
        }
        catch{
            $err = $_
        }

        It "Will throw Argument Exception" {
            $err.CategoryInfo.Reason | should be "ArgumentException"
        }
    }

    Context "When the Current Storage Account has not been set in the subscription" {
        Mock Get-AzureSubscription {@{CurrentStorageAccountName=$null}}

        try {
            Remove-AzureVMCheckpoint -VMName "vm" -CheckpointName "cp"
        }
        catch{
            $err = $_
        }

        It "Will throw Argument Exception" {
            $err.CategoryInfo.Reason | should be "InvalidOperationException"
        }
    }
}