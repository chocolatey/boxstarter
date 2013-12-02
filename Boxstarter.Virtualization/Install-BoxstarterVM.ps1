function Enable-BoxstarterVM {
    [CmdletBinding()]
    param(
        [string]$VMName,
        [string]$VMCheckpoint
    )
    $CurrentVerbosity=$global:VerbosePreference

    try {
        if($PSBoundParameters['Verbose']) {
            $global:VerbosePreference="Continue"
        }
        $vm=Get-VM $vmName -ErrorAction SilentlyContinue
        if($vm -eq $null){
            throw New-Object -TypeName InvalidOperationException -ArgumentList "Could not fine VM: $vmName"
        }
        if($vmCheckpoint -ne $null){
            Restore-VMSnapshot $vm -Name $vmCheckpoint -Confirm:$false
        }
        if($vm.State -eq "saved"){
            Remove-VMSavedState $vmName
        }
        else {
            Stop-VM $VmName -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        }
        $vhd=Get-VMHardDiskDrive -VMName $vmName
        $VHDPath = $vhd.Path

        if((Get-ItemProperty $VHDPath -Name IsReadOnly).IsReadOnly){
            throw New-Object -TypeName InvalidOperationException -ArgumentList "The VHD is Read-Only"
        }    
        $before = (Get-Volume).DriveLetter
        mount-vhd $VHDPath
        $after = (Get-Volume).DriveLetter
        $winVolume = compare $before $after -Passthru
        try{
            Get-PSDrive | Out-Null
            $winVolume = $winVolume | ? {Test-Path "$($_):\windows\System32\config"}
            if($winVolume -eq $null){
                throw New-Object -TypeName InvalidOperationException -ArgumentList "The VHD does not contain system volume"
            }    
            Write-BoxstarterMessage "Mounted VHD with system volume to Drive $($winVolume)" -Verbose
            reg load HKLM\VHDSOFTWARE "$($winVolume):\windows\system32\config\software" | out-null
            $policyResult = reg add HKLM\VHDSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\system /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f
            Write-BoxstarterMessage "Enabled LocalAccountTokenFilterPolicy with result: $policyResult" -Verbose

            reg load HKLM\VHDSYS "$($winVolume):\windows\system32\config\system" | out-null
            $current=(Get-ItemProperty "HKLM:\VHDSYS\Select" -Name Current).Current
            $computerName = (Get-ItemProperty "HKLM:\VHDSYS\ControlSet00$current\Control\ComputerName\ComputerName" -Name ComputerName).ComputerName

            $rules = Get-ItemProperty "HKLM:\VHDSYS\ControlSet00$current\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
            $rule=$rules.'WMI-RPCSS-In-TCP'
            $newVal = $rule.Replace("|Active=FALSE|","|Active=TRUE|")
            Set-ItemProperty "HKLM:\VHDSYS\ControlSet00$current\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules" -Name WMI-RPCSS-In-TCP -Value $newVal
            Write-BoxstarterMessage "Changed WMI-RPCSS-In-TCP firewall rule to: $newVal" -Verbose

            $rule=$rules.'WMI-WINMGMT-In-TCP'
            $newVal = $rule.Replace("|Active=FALSE|","|Active=TRUE|")
            Set-ItemProperty "HKLM:\VHDSYS\ControlSet00$current\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules" -Name WMI-WINMGMT-In-TCP -Value $newVal
            Write-BoxstarterMessage "Changed WMI-WINMGMT-In-TCP firewall rule to: $newVal" -Verbose
        }
        finally{
            [GC]::Collect() # The next line will fail without this since handles to the loaded hive have not yet been collected
            reg unload HKLM\VHDSOFTWARE 2>&1 | out-null
            reg unload HKLM\VHDSYS 2>&1 | out-null
            Write-BoxstarterMessage "VHD Registry Unloaded"
            Dismount-VHD $VHDPath
            Write-BoxstarterMessage "VHD Dismounted"
        }
        Start-VM $VmName
        do {Start-Sleep -milliseconds 100} 
        until ((Get-VMIntegrationService $vm | ?{$_.name -eq "Heartbeat"}).PrimaryStatusDescription -eq "OK")
        return "$computerName"
    }
    finally{
        $global:VerbosePreference=$CurrentVerbosity
    }
}