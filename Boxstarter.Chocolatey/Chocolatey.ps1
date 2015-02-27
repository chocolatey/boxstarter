function Install-ChocolateyInstallPackageOverride {
param(
  [string] $packageName, 
  [string] $fileType = 'exe',
  [string] $silentArgs = '',
  [string] $file,
  $validExitCodes = @(0)
)
    write-output "i am here"
    Wait-ForMSIEXEC
    if(Get-IsRemote){
        Invoke-FromTask @"
Import-Module $env:ChocolateyInstall\chocolateyinstall\helpers\chocolateyInstaller.psm1 -Global
Install-ChocolateyInstallPackage $(Expand-Splat $PSBoundParameters)
"@
    }
    else{
        chocolateyInstaller\Install-ChocolateyInstallPackage @PSBoundParameters
    }
}

function Write-HostOverride {
param(
  [Parameter(Position=0,Mandatory=$false,ValueFromPipeline=$true, ValueFromRemainingArguments=$true)][object] $Object,
  [Parameter()][switch] $NoNewLine, 
  [Parameter(Mandatory=$false)][ConsoleColor] $ForegroundColor, 
  [Parameter(Mandatory=$false)][ConsoleColor] $BackgroundColor,
  [Parameter(Mandatory=$false)][Object] $Separator
)
    if($Boxstarter.ScriptToCall -ne $null) { Log-BoxStarterMessage $object }

    if($Boxstarter.SuppressLogging){
        $caller = (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Name
        if("Describe","Context","write-PesterResult" -contains $caller) {
            Microsoft.PowerShell.Utility\Write-Host @PSBoundParameters
        }
        return;
    }
    try {
        chocolateyInstaller\Write-Host @PSBoundParameters
    }
    catch {
        $global:error.RemoveAt(0)
        Microsoft.PowerShell.Utility\Write-Host @PSBoundParameters
    }
}

new-alias Install-ChocolateyInstallPackage Install-ChocolateyInstallPackageOverride -force
new-alias Write-Host Write-HostOverride -force

function cinst {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    param([int[]]$RebootCodes=@())
    chocolatey Install @PSBoundParameters @args
}

function choco {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    param([int[]]$RebootCodes=@())
    chocolatey @PSBoundParameters @args
}

function cup {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    param([int[]]$RebootCodes=@())
    chocolatey Update @PSBoundParameters @args
}

function cinstm {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    param([int[]]$RebootCodes=@())
    chocolatey InstallMissing @PSBoundParameters @args
}

function chocolatey {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>  
    param([string]$command,[string]$packageNames,[string]$packageName,[string]$source,[int[]]$RebootCodes=@())
    $RebootCodes=Add-DefaultRebootCodes $RebootCodes
    $PSBoundParameters.Remove("RebootCodes") | Out-Null
    $packageNames=-split $packageNames
    Write-BoxstarterMessage "Installing $($packageNames.Count) packages" -Verbose
    #backwards compatibility for Chocolatey versions prior to 0.9.8.21
    if(!$packageNames){$packageNames=$packageName}
    $PSBoundParameters.Remove("packageName")

    foreach($packageName in $packageNames){
        $PSBoundParameters.packageNames = $packageName
        if($source -eq "WindowsFeatures"){
            $dismInfo=(DISM /Online /Get-FeatureInfo /FeatureName:$packageName)
            if($dismInfo -contains "State : Enabled" -or $dismInfo -contains "State : Enable Pending") {
                Write-BoxstarterMessage "$packageName is already installed"
                return
            }
            else{
                $winFeature=$true
            }
        }
        if(((Test-PendingReboot) -or $Boxstarter.IsRebooting) -and $Boxstarter.RebootOk) {return Invoke-Reboot}
        $session=Start-TimedSection "Calling Chocolatey to install $packageName. This may take several minutes to complete..."
        $currentErrorCount = $global:error.Count
        $rebootable = $false
        try {
            if($winFeature -eq $true -and (Get-IsRemote)){
                #DISM Output is more confusing than helpful.
                $currentLogging=$Boxstarter.Suppresslogging
                if($VerbosePreference -eq "SilentlyContinue"){$Boxstarter.Suppresslogging=$true}
                Invoke-FromTask @"
."$env:ChocolateyInstall\chocolateyinstall\chocolatey.ps1" $(Expand-Splat $PSBoundParameters)
"@
                $Boxstarter.SuppressLogging = $currentLogging
            }
            else{
                Call-Chocolatey @PSBoundParameters @args
                Write-BoxstarterMessage "Exit Code: $LastExitCode" -Verbose
                if($LastExitCode -ne $null -and $LastExitCode -ne 0) {
                    Write-Error "Chocolatey reported an unsuccessful exit code of $LastExitCode"
                }
            }
        }
        catch { 
            #Only write the error to the error stream if it was not previously
            #written by chocolatey
            $chocoErrors = $global:error.Count - $currentErrorCount
            if($chocoErrors -gt 0){
                $idx = 0
                $errorWritten = $false
                while($idx -lt $chocoErrors){
                    if(($global:error[$idx].Exception.Message | Out-String).Contains($_.Exception.Message)){
                        $errorWritten = $true
                    }
                    if(!$errorWritten){
                        Write-Error $_
                    }
                    $idx += 1
                }
            }
        }
        $chocoErrors = $global:error.Count - $currentErrorCount
        if($chocoErrors -gt 0){
            Write-BoxstarterMessage "There was an error calling chocolatey" -Verbose
            $idx = 0
            while($idx -lt $chocoErrors){
                Log-BoxstarterMessage "Error from chocolatey: $($global:error[$idx].Exception | fl * -Force | Out-String)"
                if($global:error[$idx] -match "code was '(-?\d+)'") {
                    $errorCode=$matches[1]
                    if($RebootCodes -contains $errorCode) {
                       $rebootable = $true
                    }
                }
                $idx += 1
            }
        }
        Stop-Timedsection $session
        if(!$Boxstarter.rebootOk) {continue}
        if($Boxstarter.IsRebooting){
            Remove-ChocolateyPackageInProgress $packageName
            return
        }
        if($rebootable) {
            Write-BoxstarterMessage "Chocolatey Install returned a reboot-able exit code"
            Remove-ChocolateyPackageInProgress $packageName
            Invoke-Reboot
        }
    }
}

function Call-Chocolatey {
    param($command, $packageNames)

    $psChoco = "$env:ChocolateyInstall\chocolateeyinstall\chocolatey.ps1"
    $exeChoco = "$env:ChocolateyInstall\choco.exe"

    if(Test-Path $psChoco) {
        $chocoArgs = Format-Args $args
        ."$psChoco" @PSBoundParameters @chocoArgs
    }
    elseif(Test-Path $exeChoco) {
        $chocoArgs = @($command, $packageNames)
        $chocoArgs += Format-ExeArgs $args
        if(!$global:choco){
            $global:choco = New-Object -TypeName Boxstarter.ChocolateyWrapper -ArgumentList $Boxstarter.BaseDir
        }
        Enter-BoxstarterLogable {
            $global:choco.Run($chocoArgs)
        }
    }
}

function Format-Args {
    $newArgs = @()
    $args | % {
        if($_ -is [string] -and $_.StartsWith("-") -and $_.EndsWith(":")) { $_ = $_.Substring(0,$_.length-1)}
        if($_ -eq "-source") {$hasSrc = $true}
        $newArgs += $_
    }

    if(!$hasSrc){
        $newArgs += "-Source"
        $newArgs += "$($Boxstarter.LocalRepo);$((Get-BoxstarterConfig).NugetSources)"
    }
    $newArgs
}

function Format-ExeArgs {
    $newArgs = @()
    Format-Args $args | % {
        if($onForce){
            $onForce = $false
            if($_ -eq $true) {$_ = ""}
        }
        if($_ -eq "-force"){
            $_ = "-f"
            $onForce = $true
        }
        $newArgs += $_
    }
    $newArgs
}

function Intercept-Command {
    param(
        $commandName, 
        [switch]$omitCommandParam
    )
    Write-BoxstarterMessage "Intercepting $commandName" -Verbose
    $srcMetadata=Get-MetaData $commandName
    if($srcMetadata.Parameters.count -gt 0) {
        $srcParams = [Management.Automation.ProxyCommand]::GetParamBlock($srcMetadata)    
    }
    else {
        $srcParams = "`$a"
    }
    $strContent = (Get-Content function:\$commandName).ToString()
    if($strContent -match "param\(.+\)") {
        $strContent = $strContent.Replace($matches[0],"")
    }
    Set-Item Function:\$commandName -value "param ( $srcParams )Process{ `r`n$strContent}" -force
}

function Get-MetaData ($command){
    $cmdDef = Get-Command $command | ? {$_.CommandType -ne "Application"}
    return New-Object System.Management.Automation.CommandMetaData ($cmdDef)
}

function Intercept-Chocolatey {
    if($Script:BoxstarterIntrercepting){return}
    Intercept-Command cinst -omitCommandParam
    Intercept-Command cup -omitCommandParam
    Intercept-Command cinstm -omitCommandParam
    Intercept-Command chocolatey
    Intercept-Command choco
    Intercept-Command call-chocolatey
    $Script:BoxstarterIntrercepting=$true
}

function Add-DefaultRebootCodes($codes) {
    if($codes -eq $null){$codes=@()}
    $codes += 3010 #common MSI reboot needed code
    $codes += -2067919934 #returned by SQL Server when it needs a reboot
    return $codes
}

function Remove-ChocolateyPackageInProgress($packageName) {
    $pkgDir = (dir $env:ChocolateyInstall\lib\$packageName.*)
    if($pkgDir.length -gt 0) {$pkgDir = $pkgDir[-1]}
    if($pkgDir -ne $null) {
        remove-item $pkgDir -Recurse -Force -ErrorAction SilentlyContinue  
    }
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
            if($arrayVal -is [int]){
                $ret += "$arrayVal"
            }
            else{
                $ret += "`"$arrayVal`""
            }

            $firstVal=$true
        }
        $ret += ")"
        return $ret
    }
    $ret = " `"$($val.Replace('"','`' + '"'))`""
    return $ret
}

function Wait-ForMSIEXEC{
    Write-BoxstarterMessage "Checking for other running MSIEXEC installers..." -Verbose
    Do{
        Get-Process | ? {$_.Name -eq "MSIEXEC"} | % {
            if(!($_.HasExited)){
                $proc=Get-WmiObject -Class Win32_Process -Filter "ProcessID=$($_.Id)"
                if($proc.CommandLine -ne $null -and $proc.CommandLine.EndsWith(" /V")){ break }
                Write-BoxstarterMessage "Another installer is running: $($proc.CommandLine). Waiting for it to complete..."
                $_.WaitForExit()
            }
        }
    } Until ((Get-Process | ? {$_.Name -eq "MSIEXEC"} ) -eq $null)
}