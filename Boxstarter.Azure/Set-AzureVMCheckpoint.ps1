function Set-AzureVMCheckpoint {
<#
.SYNOPSIS
Creates an Azure Blob checkpoint to capture the state of a VM

.DESCRIPTION
Creates an Azure Blob checkpoint to capture the state of a VM. This checkpoint can 
be later used to restore a VM to the state of the VM when the checkpoint was saved.

.PARAMETER $VM
The VM instance of the Azure Virtual Machine to checkpoint

.PARAMETER $CheckpointName
The Name of a the checkpoint to save

.EXAMPLE
$VM = Get-AzureVM -ServiceName "mycloudService" -Name "MyVM"
Set-AzureVMCheckpoint -VM $VM -CheckpointName "Clean"

Checkpoints MyVM with the label "clean" which can restore the VM to its current state

.LINK
http://boxstarter.org
Get-AzureVMCheckpoint
Remove-AzureVMCheckpoint
Restore-AzureVMCheckpoint
#>    
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true, Position=0)]
        [Microsoft.WindowsAzure.Commands.ServiceManagement.Model.IPersistentVM]$VM,
        [parameter(Mandatory=$true, Position=1)]
        [string]$CheckpointName
    )
    $blob=Get-blob $VM

    $existingBlob = Get-AzureVMCheckpoint -VM $VM -CheckpointName $CheckpointName
    if($existingBlob -ne $null) {
        $existingBlob.Snapshot.Delete()
    }
    $CheckpointName = "$(Get-CheckpointPrefix $VM)-$CheckpointName"
    $attributes = New-Object System.Collections.Specialized.NameValueCollection
    $attributes.Add("name",$CheckpointName)
    return $blob.CreateSnapshot($attributes, $null)
}