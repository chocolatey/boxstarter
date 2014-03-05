function Test-VMStarted {
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
                retun $true
            }
            else {
                return $false
            }
        }
    }
}