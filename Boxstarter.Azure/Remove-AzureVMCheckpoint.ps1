function Remove-AzureVMCheckpoint {
<#
.SYNOPSIS
Deletes an Azure Blob checkpoint associated with a VM

.DESCRIPTION
Deletes an Azure Blob checkpoint associated with a VM.

.PARAMETER $VMName
The Name of the Azure Virtual Machine associated with the checkpoint to delete

.PARAMETER $CheckpointName
The Name of a the checkpoint to delete

.LINK
http://boxstarter.codeplex.com
Get-AzureVMCheckpoint
Set-AzureVMCheckpoint
Restore-AzureVMCheckpoint
#>    
    param (
        [string]$VMName,
        [string]$CheckpointName
    )
    $checkpoint=Get-AzureVMCheckpoint @PSBoundParameters

    $checkpoint.Snapshot.Delete()
}