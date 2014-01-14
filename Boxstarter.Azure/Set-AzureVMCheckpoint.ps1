function Set-AzureVMCheckpoint {
<#
.SYNOPSIS
Creates an Azure Blob checkpoint to capture the state of a VM

.DESCRIPTION
Creates an Azure Blob checkpoint to capture the state of a VM. This checkpoint can 
be later used to restore a VM to the state of the VM when the checkpoint was saved.

.PARAMETER $VMName
The Name of the Azure Virtual Machine to checkpoint

.PARAMETER $CheckpointName
The Name of a the checkpoint to save

.LINK
http://boxstarter.codeplex.com
Get-AzureVMCheckpoint
Remove-AzureVMCheckpoint
Restore-AzureVMCheckpoint
#>    
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true, Position=0)]
        [string]$VMName,
        [parameter(Mandatory=$true, Position=1)]
        [string]$CheckpointName
    )
    $blob=Get-blob $VMName

    $existingBlob = Get-AzureVMCheckpoint -VMName $VMName -CheckpointName $CheckpointName
    if($existingBlob -ne $null) {
        $existingBlob.Snapshot.Delete()
    }

    $attributes = New-Object System.Collections.Specialized.NameValueCollection
    $attributes.Add("name",$CheckpointName)
    return $blob.CreateSnapshot($attributes, $null)
}