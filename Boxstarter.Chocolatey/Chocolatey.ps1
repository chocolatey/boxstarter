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
            else{
                $winFeature=$true
            }
        }
        if(((Test-PendingReboot) -or $Boxstarter.IsRebooting) -and $Boxstarter.RebootOk) {return Invoke-Reboot}
        $session=Start-TimedSection "Calling Boxstarter's vendored Chocolatey to install $packageName. This may take several minutes to complete..."
        $currentErrorCount = $global:error.Count
        $rebootable = $false
        try {
            if($winFeature -eq $true -and (Get-IsRemote)){
                #DISM Output is more confusing than helpful.
                $currentLogging=$Boxstarter.Suppresslogging
                if($VerbosePreference -eq "SilentlyContinue"){$Boxstarter.Suppresslogging=$true}
                Invoke-FromTask @"
."$($Boxstarter.VendoredChocoPath)\chocolateyinstall\chocolatey.ps1" $(Expand-Splat $PSBoundParameters)
"@
                $Boxstarter.SuppressLogging = $currentLogging
            }
            else{
                Call-Chocolatey @PSBoundParameters @args

                # chocolatey reassembles environment variables after an install
                # but does not add the machine PSModule value to the user Online
                $machineModPath = [System.Environment]::GetEnvironmentVariable("PSModulePath","Machine")
                if(!$env:PSModulePath.EndsWith($machineModPath)) {
                    $env:PSModulePath += ";" + $machineModPath
                }

                $ec = [System.Environment]::ExitCode
                Write-BoxstarterMessage "Exit Code: $ec" -Verbose
                if($ec -ne 0) {
                    Write-Error "Chocolatey reported an unsuccessful exit code of $ec. See $($Boxstarter.Log) for details."
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
                Write-BoxstarterMessage "Error from chocolatey: $($global:error[$idx].Exception | fl * -Force | Out-String)"
                if($global:error[$idx] -match "code was '(-?\d+)'") {
                    $errorCode=$matches[1]
                    if($RebootCodes -contains $errorCode) {
                       Write-BoxstarterMessage "Chocolatey Install returned a reboot-able exit code" -verbose
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
        if($candidateKeys -contains $_) { $nextIsValue = $true }
    }

    return $val
}

function Call-Chocolatey {
    param(
        [string]$command,
        [string[]]$packageNames=@('')
    )
    $chocoArgs = @($command, $packageNames)
    $chocoArgs += Format-ExeArgs @args
    Write-BoxstarterMessage "Passing the following args to chocolatey: $chocoArgs" -Verbose

    if($PSVersionTable.CLRVersion.Major -lt 4 -and (Get-IsRemote)) {
        Invoke-ChocolateyFromTask $chocoArgs
    }
    else {
        Invoke-LocalChocolatey $chocoArgs
    }

    $restartFile = "$(Get-BoxstarterTempDir)\Boxstarter.$PID.restart"
    if(Test-Path $restartFile) { 
        Write-BoxstarterMessage "found $restartFile we are restarting"
        $Boxstarter.IsRebooting = $true
        remove-item $restartFile -Force
    }
}

function Invoke-ChocolateyFromTask($chocoArgs) {
    Invoke-FromTask @"
        Import-Module $($boxstarter.BaseDir)\boxstarter.chocolatey\Boxstarter.chocolatey.psd1 -DisableNameChecking
        $(Serialize-BoxstarterVars)
        `$global:Boxstarter.Log = `$null
        `$global:Boxstarter.DisableRestart = `$true
        Export-BoxstarterVars
        `$env:BoxstarterSourcePID = $PID
        Invoke-Chocolatey $(Serialize-Array $chocoArgs)
"@ -DotNetVersion "v4.0.30319"
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

function Serialize-Array($chocoArgs) {
    $first = $false
    $res = "@("
    $chocoArgs | % {
        if($first){$res+=","}
        if($_ -is [Array]) {
            $res += Serialize-Array $_
        }
        else {
            if($_ -is [int]){
                $res += "$_"
            }
            else{
                $res += "`"$_`""
            }
        }
        $first = $true
    }
    $res += ")"
    $res
}

function Format-ExeArgs {
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
        $newArgs += $_
    }

    if((Get-PassedArg @("source","s") $args) -eq $null){
        $newArgs += "-Source"
        $newArgs += "$($Boxstarter.LocalRepo);$((Get-BoxstarterConfig).NugetSources)"
    }

    if($global:VerbosePreference -eq "Continue") {
        $newArgs += "-Verbose"
    }

    $newArgs += '-y'
    $newArgs += '--allow-unofficial'
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
    if($val -is [Array]){ return " $(Serialize-Array $val)" }
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

function Export-BoxstarterVars {
    $boxstarter.keys | % {
        if($Boxstarter[$_] -is [string] -or $Boxstarter[$_] -is [boolean]) {
            Write-BoxstarterMessage "Exporting $_ as $($Boxstarter[$_])" -verbose
            Set-Item -Path "Env:\Boxstarter.$_" -Value $Boxstarter[$_].ToString() -Force
        }
        elseif($Boxstarter[$_] -eq $null) {
            Write-BoxstarterMessage "Exporting $_ as `$null" -verbose
            Set-Item -Path "Env:\Boxstarter.$_" -Value '$null' -Force
        }
    }
    if($script:BoxstarterPassword) {
        Write-BoxstarterMessage "Exporting password as secure string" -verbose
        $env:BoxstarterPass = $script:BoxstarterPassword
    }
    if($global:VerbosePreference -eq "Continue") {
        Write-BoxstarterMessage "Exporting verbose" -verbose
        $env:BoxstarterVerbose = "True"
    }
    if($global:DebugPreference -eq "Continue") {
        Write-BoxstarterMessage "Exporting debug" -verbose
        $env:BoxstarterDebug = "True"
    }
    $env:BoxstarterSourcePID = $PID
    Write-BoxstarterMessage "Finished export" -verbose
}

function Serialize-BoxstarterVars {
    $res = ""
    $boxstarter.keys | % {
        if($Boxstarter[$_] -is [string]) {
            $res += "`$global:Boxstarter['$_']=@`"`r`n$($Boxstarter[$_])`r`n`"@`r`n"
        }
        if($Boxstarter[$_] -is [boolean]) {
            $res += "`$global:Boxstarter['$_']=`$$($Boxstarter[$_].ToString())`r`n"
        }
    }
    if($script:BoxstarterPassword) {
        $res += "`$script:BoxstarterPassword=`"$($script:BoxstarterPassword)`"`r`n"
    }
    if($global:VerbosePreference -eq "Continue") {
        $res += "`$global:VerbosePreference='Continue'`r`n"
    }
    if($global:DebugPreference -eq "Continue") {
        $res += "`$global:DebugPreference='Continue'`r`n"
    }
    Write-BoxstarterMessage "Serialized boxstarter vars to:" -verbose
    Write-BoxstarterMessage $res -verbose
    $res
}

function Import-BoxstarterVars {
    Write-BoxstarterMessage "Importing Boxstarter vars into pid $PID" -verbose
    Get-ChildItem -Path env: | ? { 
        $_.Name.StartsWith('Boxstarter.') 
    } | % {
        $key = $_.Name.Substring('Boxstarter.'.Length)
        $global:Boxstarter[$key] = $_.Value
        if($_.Value -eq 'True'){
            $global:Boxstarter[$key] = $true
        }
        if($_.Value -eq 'False'){
            $global:Boxstarter[$key] = $false
        }
        if($_.Value -eq '$null'){
            $global:Boxstarter[$key] = $null
        }
    }        

    Write-BoxstarterMessage "Imported vars set from pid: $($env:BoxstarterSourcePID)" -Verbose
    $boxstarter.keys | % {
        Write-BoxstarterMessage "$_ set to $($Boxstarter.$_)" -verbose
    }

    Get-ChildItem -Path env: | ? { 
        $_.Name.StartsWith('Boxstarter.') 
    } | remove-item

    if($env:BoxstarterPass){
        $script:BoxstarterPasswordsword = $env:BoxstarterPass
        remove-item -Path env:\BoxstarterPass
    }

    $boxstarter.SourcePID = $env:BoxstarterSourcePID

    if($env:BoxstarterVerbose -eq 'True'){
        $global:VerbosePreference = "Continue"
        remove-item -Path env:\BoxstarterVerbose
    }
    if($env:BoxstarterDebug -eq 'True'){
        $global:DebugPreference = "Continue"
        remove-item -Path env:\BoxstarterDebug
    }
}
