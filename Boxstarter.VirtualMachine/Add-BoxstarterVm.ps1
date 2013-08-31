function Add-BoxstarterVm {
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

function Add-VHDStartupScript {
    param(
        [string]$VHDPath,
        [string]$TargetScriptDirectory,
        [string[]]$FilesToCopy = @(),
        [ScriptBlock]$Script
    )    
    $volume=mount-vhd $VHDPath -Passthru | get-disk | Get-Partition | Get-Volume
    $winVolume = $volume | ? {Test-Path "$($_.DriveLetter):\windows"}
    mkdir "$($winVolume.DriveLetter):\$targetScriptDirectory"

    New-Item "$($winVolume.DriveLetter):\$targetScriptDirectory\startup.bat" -Type File -Value "powershell -ExecutionPolicy Bypass -NoProfile -File `"%SystemDrive%\$targetScriptDirectory\startup.ps1`""
    New-Item "$($winVolume.DriveLetter):\$targetScriptDirectory\startup.ps1" -Type File -Value $script.ToString()
    ForEach($file in $FilesToCopy){
        Copy-Item $file "$($winVolume.DriveLetter):\boxstarter"
    }
    $startupRegFile = "$env:Temp\startupScript.reg"
    Get-Content "$($boxstarter.BaseDir)\boxstarter.VirtualMachine\startupScript.reg" | % {
        $_ -Replace "%startupDir%", $TargetScriptDirectory
    } | Set-Content $startupRegFile
    reg load HKLM\VHDSYS "$($winVolume.DriveLetter):\windows\system32\config\software"
    reg import $startupRegFile
    reg unload HKLM\VHDSYS
    Dismount-VHD $VHDPath
}

function Enable-VMPSRemoting {
    param(
        [string]$VmName,
        [PSCredential]$Credential
    )
    $vm = Get-VM $VmName
    Stop-VM $VmName
    $vhd=Get-VMHardDiskDrive -VMName $vmName
    $fileToCopy="$($boxstarter.BaseDir)\boxstarter.VirtualMachine\EnablePsRemotingOnServer.ps1"

    Add-VHDStartupScript $vhd.Path "Boxstarter" $fileToCopy {
        netsh advfirewall firewall set rule name="File and Printer Sharing (SMB-In)" new enable=yes profile=any
        reg add HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\system /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f
    }

    Start-VM $vmName
    Write-BoxstarterMessage "Waiting for $vmName to start..."
    do {Start-Sleep -milliseconds 100} 
    until ((Get-VMIntegrationService $vm | ?{$_.name -eq "Heartbeat"}).PrimaryStatusDescription -eq "OK")
    do {Start-Sleep -milliseconds 100}
    until ((Get-GuestComputerName $vmName) -ne $null)
    $vmComputerName = Get-GuestComputerName $vmName
    PSEXEC "\\$vmComputerName" -u $Credential.UserName -p $Credential.GetNetworkCredential().Password -h powershell.exe -ExecutionPolicy Bypass -NoProfile -File "C:\Boxstarter\EnablePsRemotingOnServer.ps1"
}

function Add-BoxstarterVmSpike {
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
    write-host "\\$(Get-GuestComputerName $vmName)"
    PSEXEC "\\$(Get-GuestComputerName $vmName)" -u $creds.UserName -p $creds.GetNetworkCredential().Password -h powershell.exe -ExecutionPolicy Bypass -NoProfile -File "C:\Boxstarter\EnablePsRemotingOnServer.ps1"
    Write-BoxstarterMessage "Importing Boxstarter Module at $modPath"
    #Invoke-Command -ComputerName (Get-GuestComputerName $vmName) -Credential $creds -Authentication Credssp -ScriptBlock $script -Argumentlist $modPath,$package,$creds.Password
}

function Get-VMGuestComputerName($vmName) {
    $vm = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_ComputerSystem -Filter "ElementName='$vmName'"
    $vm.GetRelated("Msvm_KvpExchangeComponent").GuestIntrinsicExchangeItems | % {
        $GuestExchangeItemXml = ([XML]$_).SelectSingleNode("/INSTANCE/PROPERTY[@NAME='Name']/VALUE[child::text()='FullyQualifiedDomainName']") 
        
        if ($GuestExchangeItemXml -ne $null) { 
            $GuestExchangeItemXml.SelectSingleNode("/INSTANCE/PROPERTY[@NAME='Data']/VALUE/child::text()").Value 
        }    
    }    
}