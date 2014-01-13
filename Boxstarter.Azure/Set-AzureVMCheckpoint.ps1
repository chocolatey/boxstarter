function Set-AzureVMCheckpoint {
    param (
        $VM,
        [string]$CheckpointName
    )
    $blob=Get-blob $VM

    $attributes = New-Object System.Collections.Specialized.NameValueCollection
    $attributes.Add("name",$CheckpointName)
    return $blob.CreateSnapshot($attributes, $null)
}