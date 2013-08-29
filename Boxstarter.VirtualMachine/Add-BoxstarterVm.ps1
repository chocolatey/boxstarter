function Add-BoxstarterVm {
    param(
        [string]$package,
        [string]$vmName
    )
    $vm = Get-VM $VmName
    Stop-VM $VmName
    $vhd=Get-VMHardDiskDrive -VMName $vmName
    $volume=mount-vhd $vhd.Path -Passthru | get-disk | Get-Partition | Get-Volume
    $winVolume = $volume | ? {Test-Path "$($_.DriveLetter):\windows"}
    mkdir "$($winVolume.DriveLetter):\boxstarter"
    New-Item "$($winVolume.DriveLetter):\boxstarter\EnableFirewallRule.bat" -Type File -Value "netsh advfirewall firewall set rule name=`"File and Printer Sharing (SMB-In)`" new enable=yes profile=any"
    Copy-Item "$($boxstarter.BaseDir)\boxstarter.VirtualMachine\EnablePsRemotingOnServer.ps1" "$($winVolume.DriveLetter):\boxstarter"
    write-host "loading reistry"
    reg load HKLM\VHDSYS "$($winVolume.DriveLetter):\windows\system32\config\software"
    write-host "importing keys"
    reg import "c:\dev\boxstarter\boxstarter.VirtualMachine\startupScript.reg"
    reg add HKLM\VHDSYS\Microsoft\Windows\CurrentVersion\Policies\system /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f
    write-host "unloading registry"
    reg unload HKLM\VHDSYS
    Dismount-VHD $vhd.Path
    Start-VM $vmName
    $creds = Get-Credential -Message "$vmName credentials" -UserName "$env:UserDomain\$env:username"
    $me=$env:computername
    $remoteDir = $Boxstarter.BaseDir.replace(':','$')
    $encryptedPass = convertfrom-securestring -securestring $creds.password
    $modPath="\\$me\$remoteDir\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1"
    $script = {
        Import-Module $args[0]
        Invoke-ChocolateyBoxstarter $args[1] -Password $args[2]
    }
    Write-BoxstarterMessage "Waiting for $vmName to start..."
    do {Start-Sleep -milliseconds 100} 
    until ((Get-VMIntegrationService $vm | ?{$_.name -eq "Heartbeat"}).PrimaryStatusDescription -eq "OK")
    Start-Sleep -milliseconds 2000
    write-host "\\$(Get-GuestComputerName $vmName)"
    PSEXEC "\\$(Get-GuestComputerName $vmName)" -u $creds.UserName -p $creds.GetNetworkCredential().Password -h powershell.exe -ExecutionPolicy Bypass -NoProfile -File "C:\Boxstarter\EnablePsRemotingOnServer.ps1"
    Write-BoxstarterMessage "Importing Boxstarter Module at $modPath"
    #Invoke-Command -ComputerName (Get-GuestComputerName $vmName) -Credential $creds -Authentication Credssp -ScriptBlock $script -Argumentlist $modPath,$package,$creds.Password
#>
}

function Get-GuestComputerName($vmName) {
    $vm = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_ComputerSystem -Filter "ElementName='$vmName'"
    $vm.GetRelated("Msvm_KvpExchangeComponent").GuestIntrinsicExchangeItems | % {
        $GuestExchangeItemXml = ([XML]$_).SelectSingleNode("/INSTANCE/PROPERTY[@NAME='Name']/VALUE[child::text()='FullyQualifiedDomainName']") 
        
        if ($GuestExchangeItemXml -ne $null) { 
            $GuestExchangeItemXml.SelectSingleNode("/INSTANCE/PROPERTY[@NAME='Data']/VALUE/child::text()").Value 
        }    
    }    
}