function Get-Blob {
    param (
        $VM
    )
    Add-Type -Path "$env:ProgramFiles\Microsoft SDKs\Windows Azure\.NET SDK\v2.2\bin\Microsoft.WindowsAzure.StorageClient.dll"
    
    $vmOSDisk=Get-AzureOSDisk -vm $VM
    $blobURI = $vmOSDisk.MediaLink
    $blobPath = $BlobUri.LocalPath.Substring(1)

    $storageAccount = (Get-AzureSubscription).CurrentStorageAccountName
 
    #get the storage account key
    $key = (Get-AzureStorageKey -StorageAccountName $storageAccount).Primary
 
    #generate credentials based on the key
    $creds = New-Object Microsoft.WindowsAzure.StorageCredentialsAccountAndKey($storageAccount,$key)
 
    #create an instance of the CloudBlobClient class
    $blobClient = New-Object Microsoft.WindowsAzure.StorageClient.CloudBlobClient("http://$($blobUri.Host)", $creds)
 
    #and grab a reference to our target blob
    return $blobClient.GetBlobReference($blobPath)
 }