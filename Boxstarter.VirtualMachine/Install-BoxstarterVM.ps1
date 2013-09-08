function Install-BoxstarterVM {
    param(
        [string]$package,
        [string]$vmName,
        [string]$vmCheckpoint
    )
    $creds = Get-Credential -Message "$vmName credentials" -UserName "$env:UserDomain\$env:username"
    Enable-VMPSRemoting $vmName $creds

    $me=$env:computername
    $remoteDir = $Boxstarter.BaseDir.replace(':','$')
    $encryptedPass = convertfrom-securestring -securestring $creds.password
    $modPath="\\$me\$remoteDir\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1"
    $script = {
        Import-Module $args[0]
        Invoke-ChocolateyBoxstarter $args[1] -Password $args[2]
    }
    Write-BoxstarterMessage "Importing Boxstarter Module at $modPath"
    Invoke-Command -ComputerName (Get-GuestComputerName $vmName) -Credential $creds -Authentication Credssp -ScriptBlock $script -Argumentlist $modPath,$package,$creds.Password
}

function Enable-VMPSRemoting {
    param(
        [string]$VmName,
        [PSCredential]$Credential
    )
    $vm = Get-VM $VmName
    Stop-VM $VmName
    $vhd=Get-VMHardDiskDrive -VMName $vmName
    $vmComputername=Get-VHDComputerName $vhd.Path
    $fileToCopy="$($boxstarter.BaseDir)\boxstarter.VirtualMachine\EnablePsRemotingOnServer.ps1"

    Add-VHDStartupScript $vhd.Path $fileToCopy {
        netsh advfirewall firewall set rule name="File and Printer Sharing (SMB-In)" new enable=yes profile=any
        reg add HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\system /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f
    }

    Start-VM $vmName
    Write-BoxstarterMessage "Waiting for $vmName to start..."
    do {Start-Sleep -milliseconds 100} 
    until ((Get-VMIntegrationService $vm | ?{$_.name -eq "Heartbeat"}).PrimaryStatusDescription -eq "OK")
    PSEXEC "\\$vmComputerName" -u $Credential.UserName -p $Credential.GetNetworkCredential().Password -h powershell.exe -ExecutionPolicy Bypass -NoProfile -File "C:\Boxstarter\EnablePsRemotingOnServer.ps1"
}