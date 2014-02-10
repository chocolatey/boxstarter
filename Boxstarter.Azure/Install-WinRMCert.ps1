function Install-WinRMCert($VM)
{
 $winRMCert = ($VM | select -ExpandProperty vm).DefaultWinRMCertificateThumbprint
 if($winRMCert -eq $null){ 
    $X509=Get-AzureCertificate -ServiceName $vm.serviceName -ThumbprintAlgorithm sha1
    if($X509){
        $winRMCert=$X509.Thumbprint
    }
    else {
        Write-BoxstarterMessage "Could not find Certificate" -Verbose
        return
    } 
}

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