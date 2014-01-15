function Restore-AzureVMCheckpoint {
<#
.SYNOPSIS
Restores an Azure VM with a previously set checkpoint

.DESCRIPTION
Restores the state of a VM with a Blob snapshot previously created with Set-AzureVMCheckpoint.

.PARAMETER $VM
The VM instance of the Azure Virtual Machine to restore

.PARAMETER $CheckpointName
The Name of a the checkpoint to apply

.EXAMPLE
$VM = Get-AzureVM -ServiceName "mycloudService" -Name "MyVM"
Restore-AzureVMCheckpoint -VM $VM -CheckpointName "Clean"

Restores MyVM to the state it was in when the "clean" checkpoint was created

.LINK
http://boxstarter.codeplex.com
Set-AzureVMCheckpoint
Get-AzureVMCheckpoint
Remove-AzureVMCheckpoint
#>    
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true, Position=0)]
        [Microsoft.WindowsAzure.Commands.ServiceManagement.Model.IPersistentVM]$VM,
        [parameter(Mandatory=$true, Position=1)]
        [string]$CheckpointName
    )
    $checkpoint = Get-AzureVMCheckpoint $vm $CheckpointName
    if($checkpoint -eq $null) {
        throw New-Object -TypeName ArgumentException -ArgumentList "CheckpointName","No checkpoint found with name $checkpointname for VM $($VM.Name)"
    }

    $blob=Get-Blob $vm
    $serviceName = $vm.ServiceName
    $exportPath = "$env:temp\boxstarterAzureCheckpoint$($vm.Name).xml"
    $vmOSDisk=Get-AzureOSDisk -VM $VM

    Write-BoxstarterMessage "Exporting vm config for $($vm.Name) of $serviceName service to $exportPath..."
    $exportResult = Export-AzureVM -ServiceName $vm.serviceName -Name $vm.Name -Path $exportPath
    if($exportResult -eq $null) {
        throw "Unable to export VM"
    }

    Write-BoxstarterMessage "Removing Azure VM $($vm.Name)..."
    Remove-AzureVM -ServiceName $serviceName -Name $VM.Name | Out-Null

    Write-BoxstarterMessage "Waiting for disk $($vmOSDisk.DiskName) to be free..."
    do {Start-Sleep -milliseconds 100} 
    until ((Get-AzureDisk -DiskName $vmOSDisk.DiskName).AttachedTo -eq $null)

    Write-BoxstarterMessage "Removing disk $($vmOSDisk.DiskName)..."
    Remove-AzureDisk -DiskName $vmOSDisk.DiskName | Out-Null

    Write-BoxstarterMessage "Copying $($checkpoint.snapshot.Uri) to blob..."
    $blob.CopyFromBlob($checkpoint.snapshot)

    Write-BoxstarterMessage "Creating new disk from blob..."
    Add-AzureDisk -DiskName $vmOSDisk.DiskName -MediaLocation $blob.Uri -OS Windows | Out-Null

    Write-BoxstarterMessage "Creating new VM at Checkpoint..."
    Import-AzureVM -path $exportPath | New-AzureVM -ServiceName $vm.serviceName -WaitForBoot | Out-Null
 }