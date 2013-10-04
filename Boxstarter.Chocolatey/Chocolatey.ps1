function Install-ChocolateyInstallPackageOverride {
param(
  [string] $packageName, 
  [string] $fileType = 'exe',
  [string] $silentArgs = '',
  [string] $file,
  $validExitCodes = @(0)
)    
    if($PSSenderInfo.ApplicationArguments.RemoteBoxstarter -ne $null){
        Invoke-FromTask @"
Import-Module $env:ChocolateyInstall\chocolateyinstall\helpers\chocolateyInstaller.psm1
Install-ChocolateyInstallPackage $(Expand-Splat $PSBoundParameters)
"@
    }
    else{
        chocolateyInstaller\Install-ChocolateyInstallPackage @PSBoundParameters
    }
}

new-alias Install-ChocolateyInstallPackage Install-ChocolateyInstallPackageOverride -force

function cinst {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    param([int[]]$RebootCodes=@())
    chocolatey Install @PSBoundParameters
}

function cup {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    param([int[]]$RebootCodes=@())
    chocolatey Update @PSBoundParameters
}

function cinstm {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    param([int[]]$RebootCodes=@())
    chocolatey InstallMissing @PSBoundParameters
}

function chocolatey {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>  
    param([int[]]$RebootCodes=@())
    $RebootCodes=Add-DefaultRebootCodes $RebootCodes
    if($source -eq "WindowsFeatures"){
        $dismInfo=(DISM /Online /Get-FeatureInfo /FeatureName:$packageName)
        if($dismInfo -contains "State : Enabled" -or $dismInfo -contains "State : Enable Pending") {
            Write-BoxstarterMessage "$packageName is already installed"
            return
        }
    }

    if((Test-PendingReboot) -and $Boxstarter.RebootOk) {return Invoke-Reboot}
    try {Call-Chocolatey @PSBoundParameters}catch { $ex=$_}
    if(!$Boxstarter.rebootOk) {return}
    if($Boxstarter.IsRebooting){
        Remove-ChocolateyPackageInProgress $packageName
        return
    }
    if($global:error.count -gt 0) {
        if ($ex -ne $null -and ($ex -match "code was '(-?\d+)'")) {
            $errorCode=$matches[1]
            if($RebootCodes -contains $errorCode) {
                Write-BoxstarterMessage "Chocolatey Install returned a rebootable exit code"
                Remove-ChocolateyPackageInProgress $packageName
                Invoke-Reboot
            }
        }
    }
}

function Call-Chocolatey {
    $session=Start-TimedSection "Calling Chocolatey to install $packageName"
    ."$env:ChocolateyInstall\chocolateyinstall\chocolatey.ps1" @PSBoundParameters
    Stop-Timedsection $session
}

function Intercept-Command {
    param(
        $commandName, 
        $targetCommand = "$env:ChocolateyInstall\chocolateyinstall\chocolatey.ps1",
        [switch]$omitCommandParam
    )
    $metadata=Get-MetaData $targetCommand
    $srcMetadata=Get-MetaData $commandName
    if($commandName.Split("\").Length -eq 2){
        $commandName = $commandName.Substring($commandName.IndexOf("\")+1)
    }
    $metadata.Parameters.Remove("Verbose") | out-null
    $metadata.Parameters.Remove("Debug") | out-null
    $metadata.Parameters.Remove("ErrorAction") | out-null
    $metadata.Parameters.Remove("WarningAction") | out-null
    $metadata.Parameters.Remove("ErrorVariable") | out-null
    $metadata.Parameters.Remove("WarningVariable") | out-null
    $metadata.Parameters.Remove("OutVariable") | out-null
    $metadata.Parameters.Remove("OutBuffer") | out-null
    if($omitCommandParam) {
        $metadata.Parameters.Remove("command") | out-null
    }
    $params = [Management.Automation.ProxyCommand]::GetParamBlock($metadata)    
    if($srcMetadata.Parameters.count -gt 0) {
        $srcParams = [Management.Automation.ProxyCommand]::GetParamBlock($srcMetadata)    
        $params += ",`r`n" + $srcParams
    }
    $cmdLetBinding = [Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($metadata)
    $strContent = (Get-Content function:\$commandName).ToString()
    if($strContent -match "param\(.+\)") {
        $strContent = $strContent.Replace($matches[0],"")
    }
    Set-Item Function:\$commandName -value "$cmdLetBinding `r`n param ( $params )Process{ `r`n$strContent}" -force
}

function Get-MetaData ($command){
    $commandParts=$command.Split("\")
    if($commandParts.length -eq 2){
        return New-Object System.Management.Automation.CommandMetaData (Get-Command -module $commandParts[0] -name $commandParts[1])
    }
    else{
        return New-Object System.Management.Automation.CommandMetaData (Get-Command $command)
    }
}
function Intercept-Chocolatey {
    if($Script:BoxstarterIntrercepting){return}
    Intercept-Command cinst -omitCommandParam
    Intercept-Command cup -omitCommandParam
    Intercept-Command cinstm -omitCommandParam
    Intercept-Command chocolatey
    Intercept-Command call-chocolatey
    $Script:BoxstarterIntrercepting=$true
}

function Add-DefaultRebootCodes($codes) {
    if($codes -eq $null){$codes=@()}
    $codes += 3010 #common MSI reboot needed code
    $codes += -2067919934 #returned by sql server when it needs a reboot
    return $codes
}

function Remove-ChocolateyPackageInProgress($packageName) {
    $pkgDir = (dir $env:ChocolateyInstall\lib\$packageName.*)
    if($pkgDir.length -gt 0) {$pkgDir = $pkgDir[-1]}
    remove-item $pkgDir -Recurse -Force    
}

function Expand-Splat($splat){
    $ret=""
    ForEach($item in $splat.KEYS.GetEnumerator()) {
        $ret += "-$item$(Resolve-SplatValue $splat[$item]) " 
    }
    return $ret
}

function Resolve-SplatValue($val){
    if($val -is [switch]){
        if($val.IsPresent){
            return ":`$True"
        }
        else{
            return ":`$False"
        }
    }
    if($val -is [Array]){
        $ret=" @("
        $firstVal=$False
        foreach($arrayVal in $val){
            if($firstVal){$ret+=","}
            $ret += "$arrayVal"
            $firstVal=$true
        }
        $ret += ")"
        return $ret
    }
    $ret = " `"$($val.Replace('"','`' + '"'))`""
    return $ret
}