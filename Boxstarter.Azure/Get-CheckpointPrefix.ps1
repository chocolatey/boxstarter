function Get-CheckpointPrefix{
    param (
        [Microsoft.WindowsAzure.Commands.ServiceManagement.Model.IPersistentVM]$VM
    )
        return "$($VM.ServiceName)-$($VM.Name)"

}