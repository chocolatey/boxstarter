function Get-AzureVMCheckpoint {
<#
.SYNOPSIS
Retrieves Azure Blob Snapshots for a VM

.DESCRIPTION
Blob snapshots created for a VM are returned. This command can return all 
snapshots for a specific VM or for a single checkpoint specified by name.

.PARAMETER $VMName
The Name of the Azure Virtual Machine to query for checkpoints.

.PARAMETER $CheckpointName
The Name of a specific checkpoint to return. If not provided, all 
checkpoints for the VM will be returned.

.LINK
http://boxstarter.codeplex.com
Set-AzureVMCheckpoint
Remove-AzureVMCheckpoint
Restore-AzureVMCheckpoint
#>
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true, Position=0)]
        [string]$VMName,
        [parameter(Mandatory=$false, Position=1)]
        [string]$CheckpointName
    )
    $blob=Get-Blob $VMName

    $options = New-Object Microsoft.WindowsAzure.StorageClient.BlobRequestOptions
    $options.BlobListingDetails = "Snapshots,Metadata"
    $options.UseFlatBlobListing = $true
    $snapshots = $blob.Container.ListBlobs($options);

    return $snapshots | ? { 
        ($CheckpointName -eq $null -or $CheckpointName.Length -eq 0 -or $_.Metadata["name"] -eq $CheckpointName) -and $_.SnapshotTime -ne $null 
    } | % { 
        New-Object PSObject -Prop @{
            Name=$_.Metadata["name"]
            Snapshot=$_
        } 
    }
 }