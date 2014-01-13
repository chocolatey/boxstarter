function Get-AzureVMCheckpoint {
    param (
        $VM,
        [string]$CheckpointName
    )
    $blob=Get-Blob $VM

    $options = New-Object Microsoft.WindowsAzure.StorageClient.BlobRequestOptions
    $options.BlobListingDetails = "Snapshots,Metadata"
    $options.UseFlatBlobListing = $true
    $snapshots = $blob.Container.ListBlobs($options);

    return $snapshots | ? { $_.Metadata["name"] -eq $CheckpointName -and $_.SnapshotTime -ne $null }
 }