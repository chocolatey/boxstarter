function Restore-AzureVMCheckpoint {
    param (
        $VM,
        [string]$CheckpointName
    )
    $vmName = $VM.RoleName
    $snapshot = Get-AzureVMCheckpoint $VM $CheckpointName
    $blob=Get-Blob $VM
    $serviceName = (Get-AzureVM -Name $vmName).ServiceName
    $exportPath = "$env:temp\boxstarterAzureCheckpoint$vmName.xml"
    $vmOSDisk=$vm.OSVirtualHardDisk

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