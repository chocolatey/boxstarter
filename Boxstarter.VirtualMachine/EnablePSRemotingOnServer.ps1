# If not joined to a domain, set the network location as private 
if(!(1,3,4,5 -contains (Get-WmiObject win32_computersystem).DomainRole)) { 
    $networkListManager = [Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]"{DCB00C01-570F-4A9B-8D69-199FDBA5723B}")) 
    $connections = $networkListManager.GetNetworkConnections() 

    $connections | % {$_.GetNetwork().SetCategory(1)}
} 

Enable-PsRemoting -Force
Set-Item wsman:\localhost\client\trustedhosts * -Force
Enable-WSManCredSSP -Role Server -Force