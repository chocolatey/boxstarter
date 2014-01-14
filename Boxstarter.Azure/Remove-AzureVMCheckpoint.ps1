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
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true, Position=0)]
        [string]$VMName,
        [parameter(Mandatory=$true, Position=1)]
        [string]$CheckpointName
    )
    $checkpoint=Get-AzureVMCheckpoint @PSBoundParameters

    if($checkpoint -eq $null) {
        throw New-Object -TypeName ArgumentException -ArgumentList "CheckpointName","No checkpoint found with name $checkpointname for VM $VMName"
    }

    $checkpoint.Snapshot.Delete()
}