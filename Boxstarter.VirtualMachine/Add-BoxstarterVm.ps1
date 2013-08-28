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
    #New-Item "$($winVolume.DriveLetter):\boxstarter\EnablePsRemotingOnServer.bat" -Type File -Value "powershell -NoProfile -ExecutionPolicy bypass -file c:\boxstarter\EnablePsRemotingOnServer.ps1"
    New-Item "$($winVolume.DriveLetter):\boxstarter\EnablePsRemoting.bat" -Type File -Value @"
REM powershell -NoProfile -ExecutionPolicy bypass -command "Enable-PsRemoting -Force;Set-Item wsman:\localhost\client\trustedhosts * -Force;Enable-WSManCredSSP -Role Server -Force"
powershell -NoProfile -ExecutionPolicy bypass -command "new-item c:\boxstarter\test.txt -type file -value `"`"I am `$env:UserName`"`""
"@
    write-host "loading reistry"
    reg load HKLM\VHDSYS "$($winVolume.DriveLetter):\windows\system32\config\software"
    write-host "importing keys"
    reg import "c:\dev\boxstarter\boxstarter.VirtualMachine\startupScript.reg"
    write-host "unloading registry"
    reg unload HKLM\VHDSYS
    Dismount-VHD $vhd.Path
    Start-VM $vmName
    <#
    $creds = Get-Credential -Message "$vmName credentials" -UserName "$env:UserDomain\$env:username"
    $me=$env:computername
    #$remoteDir = $Boxstarter.BaseDir.replace(':','$')
    $encryptedPass = convertfrom-securestring -securestring $creds.password
    $modPath="\\$me\$remoteDir\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1"
    $script = {
        Import-Module $args[0]
        Invoke-ChocolateyBoxstarter $args[1] -Password $args[2]
    }
    Write-BoxstarterMessage "Waiting for $vmName to start..."
    do {Start-Sleep -milliseconds 100} 
    until ((Get-VMIntegrationService $vm | ?{$_.name -eq "Heartbeat"}).PrimaryStatusDescription -eq "OK")
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