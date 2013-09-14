function Enable-VMPSRemoting {
    param(
        [string]$VmName,
        [PSCredential]$Credential
    )
    $vm=Get-VM $vmName -ErrorAction SilentlyContinue
    if($vm -eq $null){
        throw New-Object -TypeName InvalidOperationException -ArgumentList "Could not fine VM: $vmName"
    }
    Stop-VM $VmName
    $vhd=Get-VMHardDiskDrive -VMName $vmName
    $vmComputername=Get-VHDComputerName $vhd.Path
    $fileToCopy="$($boxstarter.BaseDir)\boxstarter.VirtualMachine\EnablePsRemotingOnServer.ps1"

    Add-VHDStartupScript $vhd.Path -FilesToCopy $fileToCopy {
        netsh advfirewall firewall set rule name="File and Printer Sharing (SMB-In)" new enable=yes profile=any
        reg add HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\system /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f
    }

    Start-VM $vmName
    Write-BoxstarterMessage "Waiting for $vmName to start..."
    if(Wait-Port $vmComputername 445 45000){
        Invoke-PSEXEC
        return "http://$vmComputername:5985"
    }
}

function Invoke-PSEXEC {
    PSEXEC "\\$vmComputerName" -u $Credential.UserName -p $Credential.GetNetworkCredential().Password -h powershell.exe -ExecutionPolicy Bypass -NoProfile -File "C:\Boxstarter\EnablePsRemotingOnServer.ps1"
}