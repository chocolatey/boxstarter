function Get-AzureVMCheckpoint {
<#
.SYNOPSIS
Retrieves Azure Blob Snapshots for a VM

.DESCRIPTION
Blob snapshots created for a VM are returned. This command can return all 
snapshots for a specific VM or for a single checkpoint specified by name.

.PARAMETER $VM
The VM Instance of the Azure Virtual Machine to query for checkpoints.

.PARAMETER $CheckpointName
The Name of a specific checkpoint to return. If not provided, all 
checkpoints for the VM will be returned.

.EXAMPLE
$VM = Get-AzureVM -ServiceName "mycloudService" -Name "MyVM"
Get-AzureVMCheckpoint -VM $VM -CheckpointName "Clean"

Retrieves the "clean" checkpoint associated with the MyVM VM

.EXAMPLE
$VM = Get-AzureVM -ServiceName "mycloudService" -Name "MyVM"
Get-AzureVMCheckpoint -VM $VM

Retrieves all checkpoints associated with the MyVM VM

.LINK
http://boxstarter.codeplex.com
Set-AzureVMCheckpoint
Remove-AzureVMCheckpoint
Restore-AzureVMCheckpoint
#>
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true, Position=0)]
        [Microsoft.WindowsAzure.Commands.ServiceManagement.Model.IPersistentVM]$VM,
        [parameter(Mandatory=$false, Position=1)]
        [string]$CheckpointName
    )
    $blob=Get-Blob $VM
    if($CheckpointName -ne $null -and $CheckpointName.Length -gt 0){
        $CheckpointName = "$(Get-CheckpointPrefix $VM)-$CheckpointName"
    }

    $options = New-Object Microsoft.WindowsAzure.StorageClient.BlobRequestOptions
    $options.BlobListingDetails = "Snapshots,Metadata"
    $options.UseFlatBlobListing = $true
    $snapshots = $blob.Container.ListBlobs($options);

    return $snapshots | ? { 
        ($CheckpointName -eq $null -or $CheckpointName.Length -eq 0 -or $_.Metadata["name"] -eq $CheckpointName) -and $_.SnapshotTime -ne $null 
    } | % { 
        if($_.Metadata["name"].Length -gt (Get-CheckpointPrefix $VM).Length+1) {
            New-Object PSObject -Prop @{
                Name=$_.Metadata["name"].Substring((Get-CheckpointPrefix $VM).Length+1)
                Snapshot=$_
            } 
        }
    }
 }