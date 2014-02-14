function Bootstrap-Boxstarter {
    gci env: | % { write-host "$($_.key)::$($_.value)" }
    if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
        Write-Output "Chocolatey not installed. Downloading and installing..."
        $env:ChocolateyInstall = "$env:systemdrive\chocolatey"
        New-Item $env:ChocolateyInstall -Force -type directory | Out-Null
        Get-HttpToFile "http://chocolatey.org/install.ps1" "$env:temp\choco.ps1"
        . "$env:temp\choco.ps1"
    }

    if(!(Test-Path $env:ChocolateyInstall\lib\Boxstarter*)) { 
            Write-Host "Boxstarter not installed. Installing from $PSScriptRoot"
            ."$env:ChocolateyInstall\chocolateyinstall\chocolatey.ps1" Install Boxstarter.Azure -source "$PSScriptRoot" 
            Write-Host "Finished Boxstarter Install"
    }
    else {
        Write-Host "Boxstarter already installed"
    }
    if(!(Test-Path $env:ChocolateyInstall\lib\Pester*)) { ."$env:ChocolateyInstall\chocolateyinstall\chocolatey.ps1" Install Pester }

    $pesterDir = (dir $env:ChocolateyInstall\lib\Pester*)
    if($pesterDir.length -gt 0) {$pesterDir = $pesterDir[-1]}
    Import-Module "$pesterDir\tools\pester.psm1"
    if(!(Get-Module Boxstarter.Azure)){
        Import-Module $env:AppData\Boxstarter\Boxstarter.Azure\Boxstarter.Azure.psd1
    }
}

function Get-HttpToFile ($url, $file){
    Write-Output "Downloading $url to $file"
    Invoke-RetriableScript -RetryScript {
        if(Test-Path $args[1]){Remove-Item $args[1] -Force}
        $downloader=new-object net.webclient
        $wp=[system.net.WebProxy]::GetDefaultProxy()
        $wp.UseDefaultCredentials=$true
        $downloader.Proxy=$wp
        try {
            $downloader.DownloadFile($args[0], $args[1])
        }
        catch{
            Write-Error $($_.Exception | fl * -Force | Out-String)
            throw $_
        }
    } $url $file
}

function Invoke-RetriableScript{
<#
.SYNOPSIS
Retries a script 5 times or until it completes without terminating errors. 
All Unnamed args will be passed as arguments to the script
#>
    param([ScriptBlock]$RetryScript)
    $currentErrorAction=$ErrorActionPreference
    try{
        $ErrorActionPreference = "Stop"
        for($count = 1; $count -le 5; $count++) {
            try {
                Write-Verbose "Attempt #$count..."
                $ret = Invoke-Command -ScriptBlock $RetryScript -ArgumentList $args
                return $ret
                break
            }
            catch {
                if($global:Error.Count -gt 0){$global:Error.RemoveAt(0)}
                if($count -eq 5) { throw $_ }
                else { Sleep 10 }
            }
        }
    }
    finally{
        $ErrorActionPreference = $currentErrorAction
    }
}


function Set-BoxstarterAzureOptions {
    param(
        [string]$AzureSubscriptionName,
        [string]$AzureSubscriptionId,
        [string]$AzureSubscriptionCertificate
    )
    Write-Output "setting Azure Subscription Details"
    $encodedCert = [System.Convert]::FromBase64String($AzureSubscriptionCertificate)
    $CertToImport = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $encodedCert,""
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "My", "CurrentUser"
    $store.Certificates.Count
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $store.Add($CertToImport)
    $store.Close()
    Set-AzureSubscription -SubscriptionName $AzureSubscriptionName -SubscriptionId $AzureSubscriptionId -Certificate $CertToImport
    Select-AzureSubscription -SubscriptionName $AzureSubscriptionName -Default
}

Bootstrap-Boxstarter
