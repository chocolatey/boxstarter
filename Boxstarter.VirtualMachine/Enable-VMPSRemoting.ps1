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