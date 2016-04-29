function Install-ChocolateyInstallPackageOverride {
param(
  [string] $packageName, 
  [string] $fileType = 'exe',
  [string] $silentArgs = '',
  [string] $file,
  $validExitCodes = @(0)
)
    Wait-ForMSIEXEC
    if(Get-IsRemote){
        Invoke-FromTask @"
Import-Module $env:chocolateyinstall\helpers\chocolateyInstaller.psm1 -Global -DisableNameChecking
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
    $chocoWriteHost = Get-Command -Module chocolateyInstaller | ? { $_.Name -eq "Write-Host" }
    if($chocoWriteHost){
        &($chocoWriteHost) @PSBoundParameters
    }
    else {
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
    param(
        [string[]]$packageNames=@('')
    )
    chocolatey Install @PSBoundParameters @args
}

function choco {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    param(
        [string]$command,
        [string[]]$packageNames=@('')
    )
    chocolatey @PSBoundParameters @args
}

function cup {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    param(
        [string[]]$packageNames=@('')
    )
    chocolatey Update @PSBoundParameters @args
}

function chocolatey {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>  
    param(
        [string]$command,
        [string[]]$packageNames=@('')
    )
    $RebootCodes = Get-PassedArg RebootCodes $args
    $RebootCodes=Add-DefaultRebootCodes $RebootCodes
    $packageNames=-split $packageNames
    Write-BoxstarterMessage "Installing $($packageNames.Count) packages" -Verbose
    
    foreach($packageName in $packageNames){
        $PSBoundParameters.packageNames = $packageName
        if((Get-PassedArg @("source", "s") $args) -eq "WindowsFeatures"){
            $dismInfo=(DISM /Online /Get-FeatureInfo /FeatureName:$packageName)
            if($dismInfo -contains "State : Enabled" -or $dismInfo -contains "State : Enable Pending") {
                Write-BoxstarterMessage "$packageName is already installed"
                return
            }
        }
        if(((Test-PendingReboot) -or $Boxstarter.IsRebooting) -and $Boxstarter.RebootOk) {return Invoke-Reboot}
        $session=Start-TimedSection "Calling Chocolatey to install $packageName. This may take several minutes to complete..."
        $currentErrorCount = $global:error.Count
        $rebootable = $false
        try {
            [System.Environment]::ExitCode = 0
            Call-Chocolatey @PSBoundParameters @args
            $ec = [System.Environment]::ExitCode
            # suppress errors from enabled features that need a reboot
            if((Test-WindowsFeatureInstall $args) -and $ec -eq 3010) { $ec=0 }
            # chocolatey reassembles environment variables after an install
            # but does not add the machine PSModule value to the user Online
            $machineModPath = [System.Environment]::GetEnvironmentVariable("PSModulePath","Machine")
            if(!$env:PSModulePath.EndsWith($machineModPath)) {
                $env:PSModulePath += ";" + $machineModPath
            }

            Write-BoxstarterMessage "Exit Code: $ec" -Verbose
            if($ec -ne 0) {
                Write-Error "Chocolatey reported an unsuccessful exit code of $ec. See $($Boxstarter.Log) for details."
                $currentErrorCount += 1
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
                Write-BoxstarterMessage "Error from chocolatey: $($global:error[$idx].Exception | fl * -Force | Out-String)"
                if($global:error[$idx] -match "code was '(-?\d+)'") {
                    $errorCode=$matches[1]
                    if($RebootCodes -contains $errorCode) {
                       Write-BoxstarterMessage "Chocolatey Install returned a rebootable exit code" -verbose
                       $rebootable = $true
                    }
                }
                $idx += 1
            }
        }
        Stop-Timedsection $session
        if($Boxstarter.IsRebooting -or $rebootable){
            Remove-ChocolateyPackageInProgress $packageName
            Invoke-Reboot
        }
    }
}

function Get-PassedArg($argName, $origArgs) {
    $candidateKeys = @()
    $argName | % {
        $candidateKeys += "-$_"
        $candidateKeys += "--$_"
    }
    $nextIsValue = $false
    $val = $null

    $origArgs | % {
        if($nextIsValue) {
            $nextIsValue = $false
            $val =  $_
        }
        if($candidateKeys -contains $_) {
            $nextIsValue = $true
        }
        elseif($_.ToString().Contains("=")) {
            $parts = $_.split("=", 2)
            $nextIsValue = $false
            $val = $parts[1]
        }        
    }

    return $val
}

function Test-WindowsFeatureInstall($passedArgs) {
(Get-PassedArg @("source", "s") $passedArgs) -eq "WindowsFeatures"
}

function Call-Chocolatey {
    param(
        [string]$command,
        [string[]]$packageNames=@('')
    )
    $chocoArgs = @($command, $packageNames)
    $chocoArgs += Format-ExeArgs $command @args
    Write-BoxstarterMessage "Passing the following args to chocolatey: $chocoArgs" -Verbose

    $currentLogging=$Boxstarter.Suppresslogging
    try {
        if(Test-WindowsFeatureInstall $args) { $Boxstarter.SuppressLogging=$true }
        if(($PSVersionTable.CLRVersion.Major -lt 4 -or (Test-WindowsFeatureInstall $args)) -and (Get-IsRemote)) {
            Invoke-ChocolateyFromTask $chocoArgs
        }
        else {
            Invoke-LocalChocolatey $chocoArgs
        }
    }
    finally {
        $Boxstarter.SuppressLogging = $currentLogging
    }

    $restartFile = "$(Get-BoxstarterTempDir)\Boxstarter.$PID.restart"
    if(Test-Path $restartFile) { 
        Write-BoxstarterMessage "found $restartFile we are restarting"
        $Boxstarter.IsRebooting = $true
        remove-item $restartFile -Force
    }
}

function Invoke-ChocolateyFromTask($chocoArgs) {
    Invoke-BoxstarterFromTask "Invoke-Chocolatey $(Serialize-Array $chocoArgs)"
}

function Invoke-LocalChocolatey($chocoArgs) {
    if(Get-IsRemote) {
        $global:Boxstarter.DisableRestart = $true
    }
    Export-BoxstarterVars
 
    Enter-DotNet4 {
        if($env:BoxstarterVerbose -eq 'true'){
            $global:VerbosePreference = "Continue"
        }

        Import-Module "$($args[1].BaseDir)\Boxstarter.chocolatey\Boxstarter.chocolatey.psd1" -DisableNameChecking
        Invoke-Chocolatey $args[0]
    } $chocoArgs, $Boxstarter
}

function Format-ExeArgs($command) {
    $newArgs = @()
    $args | % {
        if($onForce){
            $onForce = $false
            if($_ -eq $true) {return}
            else {
                $lastIdx = $newArgs.count-2
                if($lastIdx -ge 0){
                    $newArgs = $newArgs[0..$lastIdx]
                }
                else { $newArgs = @() }
                return
            }
        }
        if([string]$_ -eq "-force:"){
            $_ = "-f"
            $onForce = $true
        }
        elseif($_.Tostring().StartsWith("-") -and $_.ToString().Contains("=")){
            $_ = $_.split("=",2)
        }

        $newArgs += $_
    }

    if((Get-PassedArg @("source","s") $args) -eq $null){
        if(@("Install","Update") -contains $command) {
            $newArgs += "-Source"
            $newArgs += "$($Boxstarter.LocalRepo);$((Get-BoxstarterConfig).NugetSources)"
        }
    }

    if($global:VerbosePreference -eq "Continue") {
        $newArgs += "-Verbose"
    }

    $newArgs += '-y'
    $newArgs
}

function Add-DefaultRebootCodes($codes) {
    if($codes -eq $null){$codes=@()}
    $codes += 3010 #common MSI reboot needed code
    $codes += -2067919934 #returned by SQL Server when it needs a reboot
    return $codes
}

function Remove-ChocolateyPackageInProgress($packageName) {
    $pkgDir = "$env:ChocolateyInstall\lib\$packageName"
    if(Test-Path $pkgDir) {
        Write-BoxstarterMessage "Removing $pkgDir in progress" -Verbose
        remove-item $pkgDir -Recurse -Force -ErrorAction SilentlyContinue  
    }
}

function Expand-Splat($splat){
    $ret=""
    ForEach($item in $splat.KEYS.GetEnumerator()) {
        $ret += "-$item$(Resolve-SplatValue $splat[$item]) " 
    }
    Write-BoxstarterMessage "Expanded splat to $ret"
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
    return " $(ConvertTo-PSString $val)"
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

function Export-BoxstarterVars {
    $boxstarter.keys | % {
        Export-ToEnvironment "Boxstarter.$_"
    }
    if($script:BoxstarterPassword) {
        Export-ToEnvironment "BoxstarterPassword" script
    }
    Export-ToEnvironment "VerbosePreference" global
    Export-ToEnvironment "DebugPreference" global
    $env:BoxstarterSourcePID = $PID
}

function Export-ToEnvironment($varToExport, $scope) {
    $val = Invoke-Expression "`$$($scope):$varToExport"
    if($val -is [string] -or $val -is [boolean]) {
        Set-Item -Path "Env:\BEX.$varToExport" -Value $val.ToString() -Force
    }
    elseif($val -eq $null) {
        Set-Item -Path "Env:\BEX.$varToExport" -Value '$null' -Force
    }
    Write-BoxstarterMessage "Exported $varToExport from $PID to `$env:BEX.$varToExport with value $val" -verbose
}

function Serialize-BoxstarterVars {
    $res = ""
    $boxstarter.keys | % {
        $res += "`$global:Boxstarter['$_']=$(ConvertTo-PSString $Boxstarter[$_])`r`n"
    }
    if($script:BoxstarterPassword) {
        $res += "`$script:BoxstarterPassword='$($script:BoxstarterPassword)'`r`n"
    }
    $res += "`$global:VerbosePreference='$global:VerbosePreference'`r`n"
    $res += "`$global:DebugPreference='$global:DebugPreference'`r`n"
    Write-BoxstarterMessage "Serialized boxstarter vars to:" -verbose
    Write-BoxstarterMessage $res -verbose
    $res
}

function Import-FromEnvironment ($varToImport, $scope) {
    if(!(Test-Path "Env:\$varToImport")) { return }
    [object]$ival = (Get-Item "Env:\$varToImport").Value.ToString()

    if($ival.ToString() -eq 'True'){ $ival = $true }
    if($ival.ToString() -eq 'False'){ $ival = $false }
    if($ival.ToString() -eq '$null'){ $ival = $null }

    Write-BoxstarterMessage "Importing $varToImport from $env:BoxstarterSourcePID to $PID with value $ival" -Verbose

    $newVar = $varToImport.Substring('BEX.'.Length)
    Invoke-Expression "`$$($scope):$newVar=$(ConvertTo-PSString $ival)"

    remove-item "Env:\$varToImport"
}

function Import-BoxstarterVars {
    Write-BoxstarterMessage "Importing Boxstarter vars into pid $PID from pid: $($env:BoxstarterSourcePID)" -verbose
    Import-FromEnvironment "BEX.BoxstarterPassword" script

    $varsToImport = @()
    Get-ChildItem -Path env: | ? { $_.Name.StartsWith('BEX.') } | % { $varsToImport += $_.Name }
    
    $varsToImport | % { Import-FromEnvironment $_ global }

    $boxstarter.SourcePID = $env:BoxstarterSourcePID
}

function ConvertTo-PSString($originalValue) {
    if($originalValue -is [int] -or $originalValue -is [int64]){
        "$originalValue"
    }
    elseif($originalValue -is [Array]){
        Serialize-Array $originalValue
    }
    elseif($originalValue -is [boolean]) {
        "`$$($originalValue.ToString())"
    }
    elseif($originalValue -ne $null){
        "`"$($originalValue.ToString().Replace('"','`' + '"'))`""
    }
    else {
        "`$null"
    }
}

function Serialize-Array($chocoArgs) {
    $first = $false
    $res = "@("
    $chocoArgs | % {
        if($first){$res+=","}
        $res += ConvertTo-PSString $_
        $first = $true
    }
    $res += ")"
    $res
}
