function Get-AzureVMCheckpoint {
<#
.SYNOPSIS
Retrieves Azure Blob Snapshots for a VM

.DESCRIPTION
Blob snapshots created for a VM are returned. This command can return all 
snapshots for a specific VM or for a single checkpoint specified by name.

.PARAMETER $VMName
The Name of the Azure Virtual Machine to query for checkpoints

.PARAMETER $CheckpointName
The Name of a specific checkpoint to return

.LINK
http://boxstarter.codeplex.com
Set-AzureVMCheckpoint
#>    
    param (
        [string]$VMName,
        [string]$CheckpointName
    )
    $blob=Get-Blob $VMName

    $options = New-Object Microsoft.WindowsAzure.StorageClient.BlobRequestOptions
    $options.BlobListingDetails = "Snapshots,Metadata"
    $options.UseFlatBlobListing = $true
    $snapshots = $blob.Container.ListBlobs($options);

    return $snapshots | ? { $_.Metadata["name"] -eq $CheckpointName -and $_.SnapshotTime -ne $null }
 }