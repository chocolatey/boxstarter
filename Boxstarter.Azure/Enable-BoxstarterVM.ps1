function Enable-BoxstarterVM {
<#
.SYNOPSIS
Finds the PowerShell Remote ConnectionURI of an Azure VM and ensures it can be accessed

.DESCRIPTION
Ensures that an Azure VM can be accessed by Boxstarter. Checks the Azure PowerShell 
SDK settings are set correctly and also examines the VM endpoints to ensure the correct 
settings for PowerShell remoting. If necessary and if running with administrative 
privileges, the WinRM certificate of the VM is downloaded and installed. If not running 
with admin privileges, a PowerShell SessionOption is used that skips the CA and CN 
check. The VM's PowerShell remoting ConnectionURI is located and returned via a 
BoxstarterConfig instance.

Enable-BoxstarterVM will also restore the VM to a specified 
checkpoint or create a new checkpoint if the given checkpoint 
does not exist.

.Parameter Provider
The VM Provider to use.

.PARAMETER CloudServiceName
The name of the Azure Cloud Service associated with the VM.

.PARAMETER VMName
The name of the VM to enable.

.PARAMETER Credential
The Credential to use to test PSRemoting.

.PARAMETER CheckpointName
If a Checkpoint exists by this name, it will be restored. Otherwise one will be created.

.NOTES
Boxstarter uses Azure Blob snapshots to create and manage VM checkpoints. These 
will not be found in the Azure portal, but you can use Boxstarter's checkpoint 
commands to manage them: Set-AzureVMCheckpoint, Get-AzureVMCheckpoint, 
Restore-AzureVMCheckpoint and Remove-AzureVMCheckpoint.

The Windows Azure PowerShell SDK and the .NET Libraries SDK are both used to 
manage the Azure VMs and Blobs.

.OUTPUTS
A BoxstarterConnectionConfig that contains the ConnectionURI of the VM Computer and 
the PSCredential needed to authenticate.

.EXAMPLE
$cred=Get-Credential AzureAdmin
New-AzureQuickVM -ServiceName MyService -Windows -Name MyVM `
  -ImageName 3a50f22b388a4ff7ab41029918570fa6__Windows-Server-2012-Essentials-20131217-enus `
  -Password $cred.GetNetworkCredential().Password -AdminUsername $cred.UserName `
  -Location "West US" -WaitForBoot
Enable-BoxstarterVM -Provider Azure -CloudServiceName MyService -VMName MyVM $cred NewSnapshot | Install-BoxstarterPackage MyPackage

Uses the Azure PowerShell SDK to create a new VM. Enable-BoxstarterVM 
then installs the WinRM certificate and obtains the VM's ConnectionURI 
which is piped to Install-BoxstarterPackage to install MyPackage.

.EXAMPLE
Enable-BoxstarterVM -Provider Azure -CloudServiceName MyService -VMName MyVM $cred

Installs the WinRM certificate associated with the VM and locates its ConnectionURI

.EXAMPLE
Enable-BoxstarterVM -Provider Azure -CloudServiceName MyService -VMName MyVM $cred | Install-BoxstarterPackage MyPackage

Obtains the VM ConnectionURI and uses that to install MyPackage

.EXAMPLE
Enable-BoxstarterVM -Provider Azure -CloudServiceName MyService -VMName MyVM $cred ExistingSnapshot | Install-BoxstarterPackage MyPackage

Gets MyVM's ConnectionURI, restores it to the state stored in ExistingSnapshot 
and then installs MyPackage

.EXAMPLE
Enable-BoxstarterVM -Provider Azure -CloudServiceName MyService -VMName MyVM $cred NewSnapshot | Install-BoxstarterPackage MyPackage

Gets MyVM's ConnectionURI, creates a new snapshot named NewSnapshot and 
then installs MyPackage

.LINK
http://boxstarter.org
Install-BoxstarterPackage
Set-AzureVMCheckpoint
Get-AzureVMCheckpoint
Restore-AzureVMCheckpoint
Remove-AzureVMCheckpoint

#>
    [CmdletBinding()]
    [OutputType([BoxstarterConnectionConfig])]
    param(
        [parameter(Mandatory=$true, Position=0)]
        [string]$CloudServiceName,
        [parameter(Mandatory=$true, ValueFromPipeline=$True, Position=1)]
        [string[]]$VMName,
        [parameter(Mandatory=$true, Position=2)]
        [Management.Automation.PsCredential]$Credential,
        [parameter(Mandatory=$false, Position=3)]
        [string]$CheckpointName
    )
    Begin {
        $CurrentVerbosity=$global:VerbosePreference

        $subscription=Get-AzureSubscription -Current
        if($subscription -eq $null){
            throw @"
Your Azure subscription information has not been sent.
Run Get-AzurePublishSettingsFile to download your Publisher settings.
Then run Import-AzurePublishSettingsFile with the settings file.
Once that is done, please run Enable-BoxstarterVM again.
"@
            return
        }

        if($PSBoundParameters["Verbose"] -eq $true) {
            $global:VerbosePreference="Continue"
        }
    }

    Process {
        try {
            $VMName | % { 
                Write-BoxstarterMessage "Locating Azure VM $_..."
                $vm = Invoke-RetriableScript { Get-AzureVM -ServiceName $args[0] -Name $args[1] } $CloudServiceName $_
                if($vm -eq $null){
                    throw New-Object -TypeName InvalidOperationException -ArgumentList "Could not find VM: $_"
                }

                if($subscription.CurrentStorageAccountName -eq $null) {
                    Write-BoxstarterMessage "Getting OS Disk" -Verbose
                    $disk=Invoke-RetriableScript { Get-AzureOSDisk -VM $args[0] } $vm
                    $endpoint="https://$($disk.MediaLink.Host)/"
                    Write-BoxstarterMessage "Getting Azure Storage Account" -Verbose
                    $storageAccount=Invoke-RetriableScript { Get-AzureStorageAccount } | ? { $_.Endpoints -contains $endpoint }
                    Set-AzureSubscription -SubscriptionName $subscription.SubscriptionName -CurrentStorageAccountName $storageAccount.Label
                }

                if($CheckpointName -ne $null -and $CheckpointName.Length -gt 0){
                    $snapshot = Get-AzureVMCheckpoint -VM $vm -CheckpointName $CheckpointName
                    if($snapshot -ne $null) {
                        Restore-AzureVMCheckpoint -VM $vm -CheckpointName $CheckpointName
                        $restored=$true
                    }
                }

                if($vm.InstanceStatus -ne "ReadyRole"){
                    Write-BoxstarterMessage "Starting Azure VM $_..."
                    Invoke-RetriableScript { Start-AzureVM -Name $args[0] -ServiceName $args[1] } $_ $CloudServiceName | Out-Null
                    Wait-ReadyState -ServiceName $CloudServiceName  -VMName $_
                }

                if(!(Test-Admin)) {
                    $PSSessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck
                }
                else {
                    Install-WinRMCert $vm | Out-Null
                }

                Write-BoxstarterMessage "Getting connection URI" -Verbose
                $uri = Invoke-RetriableScript { Get-AzureWinRMUri -serviceName $args[0] -Name $args[1] } $CloudServiceName $_
                if($uri -eq $null) {
                    throw New-Object -TypeName InvalidOperationException -ArgumentList "WinRM Endpoint is not configured on VM. Use Add-AzureEndpoint to add PowerShell remoting endpoint and use Enable-PSRemoting -Force on the VM to enable PowerShell remoting."
                }
                Write-BoxstarterMessage "URI: $uri" -Verbose
                $ComputerName=$uri.Host
                Enable-BoxstarterClientRemoting $ComputerName | out-Null
                Write-BoxstarterMessage "Testing remoting access on $ComputerName..."
                try {
                    Invoke-RetriableScript { Invoke-Command $args[0] { Get-WmiObject Win32_ComputerSystem } -Credential $args[1] -ErrorAction Stop | Out-Null } $uri $Credential 
                }
                catch {
                    Write-BoxstarterMessage "Failed to establish a remote connection with $uri. Use Enable-PSRemoting -Force on the VM to enable PowerShell remoting. Install will continue since this may be a transient error. The error encountered was $($_.ToString())" -Verbose
                }
        
                if(!$restored -and $CheckpointName -ne $null -and $CheckpointName.Length -gt 0) {
                    Write-BoxstarterMessage "Creating Checkpoint $CheckpointName for service $CloudServiceName VM $_ at $CheckpointFile"
                    Set-AzureVMCheckpoint -VM $vm -CheckpointName $CheckpointName | Out-Null
                }

                $res=new-Object -TypeName BoxstarterConnectionConfig -ArgumentList $uri,$Credential,$PSSessionOption
                return $res
            }
        }
        finally {
            $global:VerbosePreference=$CurrentVerbosity
        }
    }
}

function Wait-ReadyState($ServiceName, $vmName) {
    do {
        Start-Sleep -milliseconds 100
        Write-BoxstarterMessage "Checking VM for ReadyRole status...Hey VM!, are you ready to roll?..." -Verbose
    } 
    until (( Invoke-RetriableScript { (Get-AzureVM -ServiceName $args[0] -Name $args[1]).InstanceStatus } $ServiceName $vmName ) -eq "ReadyRole")
}