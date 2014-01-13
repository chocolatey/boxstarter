function Get-Blob {
    param (
        [string]$VMName
    )
    try {
        Add-Type -Path "$env:ProgramFiles\Microsoft SDKs\Windows Azure\.NET SDK\v2.2\bin\Microsoft.WindowsAzure.StorageClient.dll" -ErrorAction Stop
    } 
    catch {
        throw New-Object -TypeName InvalidOperationException -ArgumentList "Unable to Load types from the Azure .Net SDK. You must download and install the Windows Azure Libraries for .Net 2.2"
    }
    $vm=Get-AzureVM -Name $VMName
    if($vm -eq $null){
        throw New-Object -TypeName ArgumentException -ArgumentList "VMName","The VM with the Name provided could not be found"
    }
    $ServiceName=$vm.ServiceName

    $storageAccount = (Get-AzureSubscription).CurrentStorageAccountName
    if($storageAccount -eq $null){
        throw New-Object -TypeName InvalidOperationException -ArgumentList "The CurrentStorageAccountName has not been set. Use Set-AzureSubscription to set your current storage account"
    }

    $key = (Get-AzureStorageKey -StorageAccountName $storageAccount).Primary
    $creds = New-Object Microsoft.WindowsAzure.StorageCredentialsAccountAndKey($storageAccount,$key)

    $vmOSDisk=Get-AzureOSDisk -vm (Get-AzureVM -ServiceName $ServiceName -Name $VMName)
    $blobURI = $vmOSDisk.MediaLink
    $blobPath = $BlobUri.LocalPath.Substring(1)
    $blobClient = New-Object Microsoft.WindowsAzure.StorageClient.CloudBlobClient("http://$($blobUri.Host)", $creds)
    return $blobClient.GetBlobReference($blobPath)
 }