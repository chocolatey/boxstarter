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
        [parameter(Mandatory=$true, Position=0)]
        [string]$VMName,
        [parameter(Mandatory=$true, Position=1)]
        [Management.Automation.PsCredential]$Credential,
        [string]$CheckpointName
    )
    ##Cannot run remotely unelevated. Look into self elevating
    if(!(Test-Admin)) {
        Write-Error "You must be running as an administrator. Please open a Powershell console as Administrator and rerun Install-BoxstarperPackage."
        return
    }

    $CurrentVerbosity=$global:VerbosePreference
    try {

        if($PSBoundParameters["Verbose"] -eq $true) {
            $global:VerbosePreference="Continue"
        }

        $vm=Get-VM $vmName -ErrorAction SilentlyContinue
        if($vm -eq $null){
            throw New-Object -TypeName InvalidOperationException -ArgumentList "Could not find VM: $vmName"
        }

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

        if($vm.State -eq "running"){
            $ComputerName=Get-VMGuestComputerName $VMName
            $clientRemoting = Enable-BoxstarterClientRemoting $ComputerName
            Write-BoxstarterMessage "Testing remoting access on $ComputerName..."
            $remotingTest = Invoke-Command $ComputerName { Get-WmiObject Win32_ComputerSystem } -Credential $Credential -ErrorAction SilentlyContinue
        }
        else {
            if($vm.Notes -match "--Boxstarter Remoting Enabled Box:(.*)--"){
                $remotingTest=$true
                $ComputerName=$matches[1]
            }
        }
        
        #If the credential is a domain credential or Built in Administrator, dont change 
        #LocalAccountTokenFilterPolicy

        $params=@{}
        if(!$remotingTest -and$vm.State -eq "Running") {
            $WSManResponse = Test-WSMan $ComputerName -ErrorAction SilentlyContinue
            if($WSManResponse) { 
                $params = @{IgnoreWMI=$true} 
            }
            else {
                $wmiTest=Invoke-WmiMethod -Computer $ComputerName -Credential $Credential Win32_Process Create -Args "cmd.exe" -ErrorAction SilentlyContinue
                if($wmiTest) { 
                    $params = @{IgnoreWMI=$true} 
                }
            }
        }

        if(!$remotingTest -and$vm.State -ne "Stopped") {
            Write-BoxstarterMessage "Stopping $VMName"
            Stop-VM $VmName -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        }

        if(!$remotingTest) { 
            $vhd=Get-VMHardDiskDrive -VMName $vmName
            $computerName = Enable-BoxstarterVHD $vhd.Path @params
        }

        if($vm.State -ne"Running" ) {
            Start-VM $VmName
            Write-BoxstarterMessage "Started $VMName. Waiting for Heartbeat..."
            do {Start-Sleep -milliseconds 100} 
            until ((Get-VMIntegrationService -VMName $vmName | ?{$_.name -eq "Heartbeat"}).PrimaryStatusDescription -eq "OK")
        }

        if(!$restored -and $CheckpointName -ne $null -and $CheckpointName.Length -gt 0) {
            Write-BoxstarterMessage "Creating Checkpoint $vmCheckpoint"
            Checkpoint-VM -Name $vmName -SnapshotName $CheckpointName
        }
        Add-VMNotes $vm $ComputerName
        $res=new-Object -TypeName BoxstarterConnectionConfig -ArgumentList $computerName,$Credential
        return $res
    }
    finally{
        $global:VerbosePreference=$CurrentVerbosity
    }
}

function Get-VMGuestComputerName($vmName) {
    $vm = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_ComputerSystem -Filter "ElementName='$vmName'"
    $vm.GetRelated("Msvm_KvpExchangeComponent").GuestIntrinsicExchangeItems | % {
        $GuestExchangeItemXml = ([XML]$_).SelectSingleNode("/INSTANCE/PROPERTY[@NAME='Name']/VALUE[child::text()='FullyQualifiedDomainName']") 
        
        if ($GuestExchangeItemXml -ne $null) { 
            $GuestExchangeItemXml.SelectSingleNode("/INSTANCE/PROPERTY[@NAME='Data']/VALUE/child::text()").Value 
        }    
    }    
}

function Add-VMNotes ($VM, $ComputerName) {
    $notes = $VM.Notes
    if ($Notes -match "Boxstarter Remoting Enabled") { return }
    Set-VM -Name $VM.Name -Notes ($notes += "--Boxstarter Remoting Enabled Box:$ComputerName--")
}