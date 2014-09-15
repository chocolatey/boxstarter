function Remove-AzureVMCheckpoint {
<#
.SYNOPSIS
Deletes an Azure Blob checkpoint associated with a VM

.DESCRIPTION
Deletes an Azure Blob checkpoint associated with a VM.

.PARAMETER $VM
The VM instance of the Azure Virtual Machine associated with the checkpoint to delete

.PARAMETER $CheckpointName
The Name of a the checkpoint to delete

.EXAMPLE
$VM = Get-AzureVM -ServiceName "mycloudService" -Name "MyVM"
Remove-AzureVMCheckpoint -VM $VM -CheckpointName "Clean"

Deletes the "clean" checkpoint associated with the MyVM VM

.LINK
http://boxstarter.org
Get-AzureVMCheckpoint
Set-AzureVMCheckpoint
Restore-AzureVMCheckpoint
#>    
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true, Position=0)]
        [Microsoft.WindowsAzure.Commands.ServiceManagement.Model.IPersistentVM]$VM,
        [parameter(Mandatory=$true, Position=1)]
        [string]$CheckpointName
    )
    $checkpoint=Get-AzureVMCheckpoint @PSBoundParameters

    if($checkpoint -eq $null) {
        throw New-Object -TypeName ArgumentException -ArgumentList "CheckpointName","No checkpoint found with name $checkpointname for VM $($VM.Name)"
    }

    $checkpoint.Snapshot.Delete()
}