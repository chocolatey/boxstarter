function Set-AzureVMCheckpoint {
    param (
        [string]$VMName,
        [string]$CheckpointName
    )
    $blob=Get-blob $VMName

    $attributes = New-Object System.Collections.Specialized.NameValueCollection
    $attributes.Add("name",$CheckpointName)
    return $blob.CreateSnapshot($attributes, $null)
}