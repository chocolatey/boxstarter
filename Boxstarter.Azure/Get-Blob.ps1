function Get-Blob {
    param (
        [string]$VMName
    )
    Add-Type -Path "$env:ProgramFiles\Microsoft SDKs\Windows Azure\.NET SDK\v2.2\bin\Microsoft.WindowsAzure.StorageClient.dll"
    $ServiceName=(Get-AzureVM -Name $VMName).ServiceName
    $vmOSDisk=Get-AzureOSDisk -vm (Get-AzureVM -ServiceName $ServiceName -Name $VMName)
    $blobURI = $vmOSDisk.MediaLink
    $blobPath = $BlobUri.LocalPath.Substring(1)

    $storageAccount = (Get-AzureSubscription).CurrentStorageAccountName
    $key = (Get-AzureStorageKey -StorageAccountName $storageAccount).Primary
    $creds = New-Object Microsoft.WindowsAzure.StorageCredentialsAccountAndKey($storageAccount,$key)
 
    $blobClient = New-Object Microsoft.WindowsAzure.StorageClient.CloudBlobClient("http://$($blobUri.Host)", $creds)
    return $blobClient.GetBlobReference($blobPath)
 }