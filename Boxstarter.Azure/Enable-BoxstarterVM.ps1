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
A BoxstarterConnectionConfig that contains the DNS Name of the VM Computer and 
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
    [OutputType([BoxstarterConnectionConfig])]
    param(
        [parameter(Mandatory=$true, ValueFromPipeline=$True, Position=0)]
        [string[]]$VMName,
        [parameter(Mandatory=$true, Position=1)]
        [Management.Automation.PsCredential]$Credential,
        [string]$CheckpointName
    )
    Begin {
        ##Cannot run remotely unelevated. Look into self elevating
        if(!(Test-Admin)) {
            Write-Error "You must be running as an administrator. Please open a Powershell console as Administrator and rerun Install-BoxstarperPackage."
            return
        }

        ###Validate that the VM and Azure account is good.

        $CurrentVerbosity=$global:VerbosePreference

        if($PSBoundParameters["Verbose"] -eq $true) {
            $global:VerbosePreference="Continue"
        }
    }

    Process {
        $VMName | % { 
            $checkpointDirectory = Join-Path $Boxstarter.BaseDir "Boxstarter.Azure.Checkpoints"
            if(!(Test-Path $checkpointDirectory)){ Mkdir $checkpointDirectory | Out-Null }
            $checkpointFile= Join-Path $checkpointDirectory $CheckpointName-$_.xml

            Write-BoxstarterMessage "Locating Azure VM $_..."
            $vm=Get-AzureVM -Name $_
            if($vm -eq $null){
                throw New-Object -TypeName InvalidOperationException -ArgumentList "Could not find VM: $_"
            }

            $serviceName = $VM.ServiceName

            if($CheckpointName -ne $null -and $CheckpointName.Length -gt 0){
                if(Test-Path  $checkpointFile) {
                    Write-BoxstarterMessage "Removing Azure VM $_..."
                    $removedVMDisk=Get-AzureOSDisk -vm (Get-AzureVM -ServiceName $serviceName -Name $_ | select -ExpandProperty vm)
                    Remove-AzureVM -ServiceName $ServiceName -Name $_ | Out-Null
                    $disk = $removedVMDisk.DiskName
                    Write-BoxstarterMessage "Waiting for disk $disk to be free..."
                    do {Start-Sleep -milliseconds 100} 
                    until ((Get-AzureDisk -DiskName $disk).AttachedTo -eq $null)
                    Write-BoxstarterMessage "$checkpointName restoring on $_. Waiting to complete..."
                    Import-AzureVM -path $checkpointFile | New-AzureVM -ServiceName $serviceName -WaitForBoot | Out-Null
                    $restored=$true
                }
            }

            if($vm.Status -ne "ReadyRole"){
                Write-BoxstarterMessage "Starting Azure VM $_..."
                Start-AzureVM -Name $_ -ServiceName $serviceName
                Wait-ReadyState $_
            }

            Install-WinRMCert -ServiceName $serviceName -VMName $_
            $uri = Get-AzureWinRMUri -serviceName $serviceName -Name $_
            $ComputerName=$uri.Host
            $clientRemoting = Enable-BoxstarterClientRemoting $ComputerName
            Write-BoxstarterMessage "Testing remoting access on $ComputerName..."
            $remotingTest = Invoke-Command $uri { Get-WmiObject Win32_ComputerSystem } -Credential $Credential -ErrorAction SilentlyContinue
            if(!$remotingTest) {
                Write-BoxstarterMessage "Unable to establish a remote connection with $_"
            }
        
            if(!$restored -and $CheckpointName -ne $null -and $CheckpointName.Length -gt 0) {
                Write-BoxstarterMessage "Creating Checkpoint $CheckpointName for service $serviceName VM $_ at $CheckpointFile"
                Export-AzureVM -ServiceName $serviceName -Name $_ -Path $CheckpointFile | Out-Null
            }

            $res=new-Object -TypeName BoxstarterConnectionConfig -ArgumentList $uri,$Credential
            return $res
        }
    }

    End {
        $global:VerbosePreference=$CurrentVerbosity
    }
}

function Wait-ReadyState($vmName) {
    do {Start-Sleep -milliseconds 100} 
    until ((Get-AzureVM -Name $vmName).Status -eq "ReadyRole")
}