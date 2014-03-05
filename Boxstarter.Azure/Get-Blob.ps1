function Get-Blob {
    param (
        [Microsoft.WindowsAzure.Commands.ServiceManagement.Model.IPersistentVM]$VM
    )
    $ServiceName=$vm.ServiceName

    $storageAccount = (Get-AzureSubscription -current).CurrentStorageAccountName
    if($storageAccount -eq $null){
        throw New-Object -TypeName InvalidOperationException -ArgumentList "The CurrentStorageAccountName has not been set. Use Set-AzureSubscription to set your current storage account"
    }

    Write-BoxstarterMessage "Getting azure storage key..." -Verbose
    $key = Invoke-RetriableScript { (Get-AzureStorageKey -StorageAccountName $args[0]).Primary } $storageAccount
    $creds = New-Object Microsoft.WindowsAzure.StorageCredentialsAccountAndKey($storageAccount,$key)

    Write-BoxstarterMessage "Getting OS disk..." -Verbose
    $vmOSDisk=Invoke-RetriableScript { Get-AzureOSDisk -vm $args[0] } $VM
    $blobURI = $vmOSDisk.MediaLink
    $blobPath = $BlobUri.LocalPath.Substring(1)
    $blobClient = New-Object Microsoft.WindowsAzure.StorageClient.CloudBlobClient("http://$($blobUri.Host)", $creds)
    return $blobClient.GetBlobReference($blobPath)
 }