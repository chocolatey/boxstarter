function Test-VMStarted {
<#
.SYNOPSIS
Checks if an Azure VM is in a running state

.DESCRIPTION
If the VM is running, Test-VMStarted returns $true

.PARAMETER CloudServiceName
The name of the Azure Cloud Service associated with the VM.

.PARAMETER VMName
The name of the VM to enable.

.EXAMPLE
$isStarted = Test-VMStarted -ServiceName "mycloudService" -Name "MyVM"

$isStarted will be $true if MyVM is running

.LINK
http://boxstarter.codeplex.com
Enable-BoxstarterVM
#>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true, Position=0)]
        [string]$CloudServiceName,
        [parameter(Mandatory=$true, ValueFromPipeline=$True, Position=1)]
        [string[]]$VMName
    )

    Process {
        $VMName | % { 
            $vm = Invoke-RetriableScript { Get-AzureVM -ServiceName $args[0] -Name $args[1] } $CloudServiceName $_
            if($vm -eq $null){
                throw New-Object -TypeName InvalidOperationException -ArgumentList "Could not find VM: $_"
            }
            if($vm.InstanceStatus -eq "ReadyRole"){
                Write-BoxStarterMessage "Testing service $CloudServiceName vm $_. VM is in ReadyRole." -verbose
                return $true
            }
            else {
                Write-BoxStarterMessage "Testing service $CloudServiceName vm $_. VM is not in ReadyRole. Role: $($vm.InstanceStatus)" -verbose
                return $false
            }
        }
    }
}