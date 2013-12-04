function Enable-BoxstarterVHD {
<#
.SYNOPSIS
Enables WMI and LocalAccountTokenFilterPolicy in a VHD's Windows Registry

.DESCRIPTION
Prepares a VHD for Boxstarter Installation. Opening WMI ports and enabling 
LocalAccountTokenFilterPolicy so that Boxstarter can later enable 
PowerShell Remoting.

.PARAMETER VHDPath
The path to ther VHD file

.OUTPUTS
The computer name stored in the VHD's Windows Registry

.EXAMPLE
$ComputerName = Enable-BoxstarterVHD $pathToVHD

.LINK
http://boxstarter.codeplex.com

#>
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateScript({Test-Path $_})]
        [ValidatePattern("\.(a)?vhd(x)?$")]
        [string]$VHDPath
    )
    Invoke-Verbosely -Verbose:($PSBoundParameters['Verbose'] -eq $true) {
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
            $current=Get-CurrentControlSet
            $computerName = (Get-ItemProperty "HKLM:\VHDSYS\ControlSet00$current\Control\ComputerName\ComputerName" -Name ComputerName).ComputerName

            Enable-FireWallRule WMI-RPCSS-In-TCP
            Enable-FireWallRule WMI-WINMGMT-In-TCP

            return "$computerName"
        }
        finally{
            [GC]::Collect() # The next line will fail without this since handles to the loaded hive have not yet been collected
            reg unload HKLM\VHDSOFTWARE 2>&1 | out-null
            reg unload HKLM\VHDSYS 2>&1 | out-null
            Write-BoxstarterMessage "VHD Registry Unloaded" -Verbose
            Dismount-VHD $VHDPath
            Write-BoxstarterMessage "VHD Dismounted" -Verbose
        }
    }
}

function Enable-FireWallRule($ruleName){
    $key=Get-FirewallKey
    $rules = Get-ItemProperty $key
    $rule=$rules.$ruleName
    $newVal = $rule.Replace("|Active=FALSE|","|Active=TRUE|")
    Set-ItemProperty $key -Name $ruleName -Value $newVal
    Write-BoxstarterMessage "Changed $ruleName firewall rule to: $newVal" -Verbose
}

function Disable-FireWallRule($ruleName){
    $key=Get-FirewallKey
    $rules = Get-ItemProperty $key
    $rule=$rules.$ruleName
    $newVal = $rule.Replace("|Active=TRUE|","|Active=FALSE|")
    Set-ItemProperty $key -Name $ruleName -Value $newVal
    Write-BoxstarterMessage "Changed $ruleName firewall rule to: $newVal" -Verbose
}

function Get-FireWallKey{
    $current = Get-CurrentControlSet
    return "HKLM:\VHDSYS\ControlSet00$current\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
}

function Get-CurrentControlSet {
    return (Get-ItemProperty "HKLM:\VHDSYS\Select" -Name Current).Current

}