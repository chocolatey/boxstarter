function Enable-BoxstarterVM {
<#
.SYNOPSIS
Opens WMI ports and LocalAccountTokenFilterPolicy for Workgroup Hyper-V VMs

.DESCRIPTION
Prepares a Hyper-V VM for Boxstarter Installation. Opening WMI 
ports if remoting is not enabled and enabling 
LocalAccountTokenFilterPolicy if the VM is not in a domain so 
that Boxstarter can later enable PowerShell Remoting.

Enable-BoxstarterVM will also restore the VM to a specified 
checkpoint or create a new checkpoint if the given checkpoint 
does not exist.

.Parameter Provider
The VM Provider to use.

.PARAMETER VMName
The name of the VM to enable.

.PARAMETER Credential
The Credential to use to test PSRemoting.

.PARAMETER CheckpointName
If a Checkpoint exists by this name, it will be restored. Otherwise one will be created.

.NOTES
PSRemoting must be enabled in order for Boxstarter to install to a remote machine. Bare 
Metal machines require a manual step of enabling it before remote Boxstarter installs 
will work. However, on a Hyper-V VM, Boxstarter can manage this by mounting and 
manipulating the VM's VHD. Boxstarter can open the WMI ports which enable it to create a 
Scheduled Task that will enable PSRemoting. For VMs that are not domain joined, 
Boxstarter will also enable LocalAccountTokenFilterPolicy so that local accounts can 
authenticate remotely.

For Non-HyperV VMs, use Enable-BoxstarterVHD to perform these adjustments on the VHD of 
the VM. The VM must be powered off and accessible.

.OUTPUTS
A BoxstarterConnectionConfig that contains the ConnectionURI of the VM Computer and 
the PSCredential needed to authenticate.

.EXAMPLE
$cred=Get-Credential domain\username
Enable-BoxstarterVM -Provider HyperV -VMName MyVM $cred

Prepares MyVM for a Boxstarter Installation

.EXAMPLE
Enable-BoxstarterVM -Provider HyperV -VMName MyVM $cred | Install-BoxstarterPackage MyPackage

Prepares MyVM and then installs MyPackage

.EXAMPLE
Enable-BoxstarterVM -Provider HyperV -VMName MyVM $cred ExistingSnapshot | Install-BoxstarterPackage MyPackage

Prepares MyVM, Restores ExistingSnapshot and then installs MyPackage

.EXAMPLE
Enable-BoxstarterVM -Provider HyperV -VMName MyVM $cred NewSnapshot | Install-BoxstarterPackage MyPackage

Prepares MyVM, Creates a new snapshot named NewSnapshot and then installs MyPackage

.LINK
http://boxstarter.org
Enable-BoxstarterVHD
Install-BoxstarterPackage
#>
    [CmdletBinding()]
    [OutputType([BoxstarterConnectionConfig])]
    param(
        [parameter(Mandatory=$true, ValueFromPipeline=$True, Position=0)]
        [string[]]$VMName,
        [parameter(Mandatory=$true, Position=1)]
        [Management.Automation.PsCredential]$Credential,
        [parameter(Mandatory=$false, Position=2)]
        [string]$CheckpointName
    )
    Begin {
        ##Cannot run remotely unelevated. Look into self elevating
        if(!(Test-Admin)) {
            Write-Error "You must be running as an administrator. Please open a PowerShell console as Administrator and rerun Install-BoxstarperPackage."
            return
        }

        if(!(Get-Command -Name Get-VM -ErrorAction SilentlyContinue)){
            Write-Error "Boxstarter could not find the Hyper-V PowerShell Module installed. This is required for use with Boxstarter.HyperV. Run Install-windowsfeature -name hyper-v -IncludeManagementTools."
            return
        }

        $CurrentVerbosity=$global:VerbosePreference

        if($PSBoundParameters["Verbose"] -eq $true) {
            $global:VerbosePreference="Continue"
        }
    }

    Process {
        $VMName | % { 

            $vm=Get-VM $_ -ErrorAction SilentlyContinue
            if($vm -eq $null){
                throw New-Object -TypeName InvalidOperationException -ArgumentList "Could not find VM: $_"
            }

            if($CheckpointName -ne $null -and $CheckpointName.Length -gt 0){
                $point = Get-VMSnapshot -VMName $_ -Name $CheckpointName -ErrorAction SilentlyContinue
                $origState=$vm.State
                if($point -ne $null) {
                    Restore-VMSnapshot -VMName $_ -Name $CheckpointName -Confirm:$false
                    Write-BoxstarterMessage "$checkpointName restored on $_ waiting to complete..."
                    $restored=$true
                }
            }

            if($vm.State -eq "saved"){
                Remove-VMSavedState $_
            }

            if($vm.State -ne "running"){
                Start-VM $_ -ErrorAction SilentlyContinue
                Wait-HeartBeat $_
            }

            do {
                Start-Sleep -milliseconds 100
                $ComputerName=Get-VMGuestComputerName $_
            } 
            until ($ComputerName -ne $null)
            $clientRemoting = Enable-BoxstarterClientRemoting $ComputerName
            Write-BoxstarterMessage "Testing remoting access on $ComputerName..."
            $remotingTest = Invoke-Command $ComputerName { Get-WmiObject Win32_ComputerSystem } -Credential $Credential -ErrorAction SilentlyContinue
        
            $params=@{}
            if(!$remotingTest) {
                Log-BoxstarterMessage "PowerShell remoting connection failed:"
                if($global:Error.Count -gt 0) { Log-BoxstarterMessage $global:Error[0] }
                write-BoxstarterMessage "Testing WSMAN..."
                $WSManResponse = Test-WSMan $ComputerName -ErrorAction SilentlyContinue
                if($WSManResponse) { 
                    Write-BoxstarterMessage "WSMAN responded. Will not enable WMI." -verbose
                    $params["IgnoreWMI"]=$true
                }
                else {
                    Log-BoxstarterMessage "WSMan connection failed:"
                    if($global:Error.Count -gt 0) { Log-BoxstarterMessage $global:Error[0] }
                    write-BoxstarterMessage "Testing WMI..."
                    $wmiTest=try { Invoke-WmiMethod -ComputerName $ComputerName -Credential $Credential Win32_Process Create -Args "cmd.exe" -ErrorAction SilentlyContinue } catch {$ex=$_}
                    if($wmiTest -or ($ex -ne $null -and $ex.CategoryInfo.Reason -eq "UnauthorizedAccessException")) { 
                        Write-BoxstarterMessage "WMI responded. Will not enable WMI." -verbose
                        $params["IgnoreWMI"]=$true
                    }
                    else {
                        Log-BoxstarterMessage "WMI connection failed:"
                        if($global:Error.Count -gt 0) { Log-BoxstarterMessage $global:Error[0] }
                    }
                }
                $credParts = $Credential.UserName.Split("\\")
                if(($credParts.Count -eq 1 -and $credParts[0] -eq "administrator") -or `
                  ($credParts.Count -eq 2 -and $credParts[0] -eq $ComputerName -and $credParts[1] -eq "administrator") -or`
                  ($credParts.Count -eq 2 -and $credParts[0] -ne $ComputerName)){
                    $params["IgnoreLocalAccountTokenFilterPolicy"]=$true
                }
                if($credParts.Count -eq 2 -and $credParts[0] -eq $ComputerName -and $credParts[1] -eq "administrator"){
                    $params["IgnoreLocalAccountTokenFilterPolicy"]=$true
                }

            }

            if(!$remotingTest -and ($params.Count -lt 2)) { 
                Write-BoxstarterMessage "Stopping $_"
                Stop-VM $_ -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                $vhd=Get-VMHardDiskDrive -VMName $_
                Enable-BoxstarterVHD $vhd.Path @params | Out-Null
                Start-VM $_
                Write-BoxstarterMessage "Started $_. Waiting for Heartbeat..."
                Wait-HeartBeat $_
            }

            if(!$restored -and $CheckpointName -ne $null -and $CheckpointName.Length -gt 0) {
                Write-BoxstarterMessage "Creating Checkpoint $CheckpointName"
                Checkpoint-VM -Name $_ -SnapshotName $CheckpointName
            }

            $res=new-Object -TypeName BoxstarterConnectionConfig -ArgumentList "http://$($computerName):5985/wsman",$Credential,$null
            return $res
        }
    }

    End {
        $global:VerbosePreference=$CurrentVerbosity
    }
}

function Get-VMGuestComputerName($vmName) {
    $vm = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_ComputerSystem -Filter "ElementName='$vmName'"
    $vm.GetRelated("Msvm_KvpExchangeComponent").GuestIntrinsicExchangeItems | % {
        if(([XML]$_) -ne $null){
            $GuestExchangeItemXml = ([XML]$_).SelectSingleNode("/INSTANCE/PROPERTY[@NAME='Name']/VALUE[child::text()='FullyQualifiedDomainName']") 
        
            if ($GuestExchangeItemXml -ne $null) { 
                $GuestExchangeItemXml.SelectSingleNode("/INSTANCE/PROPERTY[@NAME='Data']/VALUE/child::text()").Value 
            }
        }
    }    
}

function Wait-HeartBeat($vmName) {
    do {Start-Sleep -milliseconds 100} 
    until ((Get-VMIntegrationService -VMName $vmName | ?{$_.id.endswith("\\84EAAE65-2F2E-45F5-9BB5-0E857DC8EB47") -or ($_.name -eq "Heartbeat")}).PrimaryStatusDescription -eq "OK")
}