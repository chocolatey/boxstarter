function Enable-BoxstarterVM {
<#
.SYNOPSIS
Opens WMI ports and LocalAccountTokenFilterPolicy for workgroup Hyper-V VMs

.DESCRIPTION
Prepares a Hyper-V VM for Boxstarter Installation. Opening WMI 
ports if remoting is not enabled and enabling 
LocalAccountTokenFilterPolicy if the VM is not in a domain so 
that Boxstarter can later enable PowerShell Remoting.

Enable-BoxstarterVM will also restore the VM to a specified 
checkpoint or create a new checkpoint if the given checkpoint 
does not exist.

.PARAMETER VMName
The name of the VM to enable.

.PARAMETER Credential
The Credential to use to test PSRemoting.

.PARAMETER CheckpointName
If a Checkpoint exists by this name, it will be restored. Otherwise one will be created.

.NOTES
PSRemoting mut be enabled in order for Boxstarter to install to a remote machine. Bare 
Metal machines require a manual step of enabling it before remote Boxstarter installs 
will work. However, on a Hyper-V VM, Boxstarter can manage this by mounting and 
manipulating the VM's VHD. Boxstarter can open the WMI ports which enable it to create a 
Scheduled Task that will enable PSRemoting. For VMs that are not domain joined, 
Boxstarter will also enable LocalAccountTokenFilterPolicy so that local accounts can 
authenticate remotely.

For Non-HyperV VMs, use Enable-BoxstarterVHD to perform these adjustments on the VHD of 
the VM. The VM must be powered off and accesible.

.OUTPUTS
A BoxstarterConnectionTokens object that contains the DNS Name of the VM Computer and 
the PSCredential needed to authenticate.

.EXAMPLE
Enable-BoxstarterVM MyVM $cred

Prepares MyVM for a Boxstarter Installation

.EXAMPLE
Enable-BoxstarterVM MyVM $cred | Install-BoxstarterPackage MyPackage

Prepares MyVM and then installs MyPackage

.EXAMPLE
Enable-BoxstarterVM MyVM $cred ExistingSnapshot | Install-BoxstarterPackage MyPackage

Prepares MyVM, Restores ExistingSnapshot and then installs MyPackage

.EXAMPLE
Enable-BoxstarterVM MyVM $cred NewSnapshot | Install-BoxstarterPackage MyPackage

Prepares MyVM, Creates a new snapshot named NewSnapshot and then installs MyPackage

.LINK
http://boxstarter.codeplex.com

#>
    [CmdletBinding()]
    param(
        [string]$VMName,
        [Management.Automation.PsCredential]$Credential,
        [string]$CheckpointName
    )
    Invoke-Verbosely -Verbose:($PSBoundParameters['Verbose'] -eq $true) {
        $vm=Get-VM $vmName -ErrorAction SilentlyContinue
        if($vm -eq $null){
            throw New-Object -TypeName InvalidOperationException -ArgumentList "Could not find VM: $vmName"
        }

        #Get Computername from key/value pair
        #Check for client remoting enabled
        #Test remoting
        #Test WMI

        if($CheckpointName -ne $null -and $CheckpointName.Length -gt 0){
            $point = Get-VMSnapshot -VMName $vmName -Name $CheckpointName -ErrorAction SilentlyContinue
            if($point -ne $null) {
                Restore-VMSnapshot -VMName $vmName -Name $CheckpointName -Confirm:$false
                $restored=$true
            }
        }
        if($vm.State -eq "saved"){
            Remove-VMSavedState $vmName
        }
        else {
            Write-BoxstarterMessage "Stopping $VMName"
            Stop-VM $VmName -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        }
        $vhd=Get-VMHardDiskDrive -VMName $vmName

        $computerName = Enable-BoxstarterVHD $vhd.Path
        Start-VM $VmName
        Write-BoxstarterMessage "Started $VMName. Waiting for Heartbeat..."
        do {Start-Sleep -milliseconds 100} 
        until ((Get-VMIntegrationService -VMName $vmName | ?{$_.name -eq "Heartbeat"}).PrimaryStatusDescription -eq "OK")
        if(!$restored -and $CheckpointName -ne $null -and $CheckpointName.Length -gt 0) {
            Write-BoxstarterMessage "Creating Checkpoint $vmCheckpoint"
            Checkpoint-VM -Name $vmName -SnapshotName $CheckpointName
        }
        return "$computerName"
    }
}