function Restore-AzureVMCheckpoint {
    param (
        [string]$VMName,
        [string]$CheckpointName
    )
    $snapshot = Get-AzureVMCheckpoint $vmName $CheckpointName
    $blob=Get-Blob $vmName
    $vm=Get-AzureVM -Name $vmName
    $serviceName = $vm.ServiceName
    $exportPath = "$env:temp\boxstarterAzureCheckpoint$vmName.xml"
    $vmOSDisk=Get-AzureOSDisk -VM (Get-AzureVM -ServiceName $serviceName -Name $VMName)

    Write-BoxstarterMessage "Exporting vm config for $vmName of $serviceName service to $exportPath..."
    $exportResult = Export-AzureVM -ServiceName $serviceName -Name $vmName -Path $exportPath
    if($exportResult -eq $null) {
        throw "Unable to export VM"
    }

    Write-BoxstarterMessage "Removing Azure VM $vmName..."
    Remove-AzureVM -ServiceName $ServiceName -Name $vmName | Out-Null

    Write-BoxstarterMessage "Waiting for disk $($vmOSDisk.DiskName) to be free..."
    do {Start-Sleep -milliseconds 100} 
    until ((Get-AzureDisk -DiskName $vmOSDisk.DiskName).AttachedTo -eq $null)

    Write-BoxstarterMessage "Removing disk $($vmOSDisk.DiskName)..."
    Remove-AzureDisk -DiskName $vmOSDisk.DiskName | Out-Null

    Write-BoxstarterMessage "Copying $($snapshot.Uri) to blob..."
    $blob.CopyFromBlob($snapshot)

    Write-BoxstarterMessage "Creating new disk from blob..."
    Add-AzureDisk -DiskName $vmOSDisk.DiskName -MediaLocation $blob.Uri -OS Windows | Out-Null

    Write-BoxstarterMessage "Creating new VM at Checkpoint..."
    Import-AzureVM -path $exportPath | New-AzureVM -ServiceName $serviceName -WaitForBoot | Out-Null
 }