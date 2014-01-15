<#
Get-AzurePublishSettingsFile
Import-AzurePublishSettingsFile C:\Users\Matt\Downloads\Subscription-1-1-5-2014-credentials.publishsettings
Install-WinRMCert -serviceName wrockcraft2 -vmname wrockcraft
Get-AzureWinRMUri -serviceName wrockcraft2 -vmname wrockcraft | Enter-pssession -Credential $c
#>
function Install-WinRMCert($VM)
{
 $winRMCert = ($VM | select -ExpandProperty vm).DefaultWinRMCertificateThumbprint
 if($winRMCert -eq $null){ return }

 Write-BoxstarterMessage "Installing WinRM Certificate"
 $AzureX509cert = Get-AzureCertificate -ServiceName $vm.serviceName -Thumbprint $winRMCert -ThumbprintAlgorithm sha1
 
 $certTempFile = [IO.Path]::GetTempFileName()
 $AzureX509cert.Data | Out-File $certTempFile
 
 # Target The Cert That Needs To Be Imported
 $CertToImport = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $certTempFile
 
 $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "Root", "LocalMachine"
 $store.Certificates.Count
 $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
 $store.Add($CertToImport)
 $store.Close()
 
 Remove-Item $certTempFile
}