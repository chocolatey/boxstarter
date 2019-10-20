
function Install-ChocolateyInstallPackageOverride {
    param(
        [string]
        $packageName,
        
        [string]
        $fileType = 'exe',
        
        [string]
        $silentArgs = '',

        [alias("fileFullPath")]
        [string] 
        $file,

        [alias("fileFullPath64")]
        [string] 
        $file64,

        [int[]]
        $validExitCodes = @(0)
    )

    Wait-ForMSIEXEC
    if (Get-IsRemote) {
        Invoke-FromTask @"
Import-Module $env:chocolateyinstall\helpers\chocolateyInstaller.psm1 -Global -DisableNameChecking
Install-ChocolateyInstallPackage $(Expand-Splat $PSBoundParameters)
"@
    }
    else {
        chocolateyInstaller\Install-ChocolateyInstallPackage @PSBoundParameters
    }
}

function Write-HostOverride {
    param(
        [Parameter(Position = 0, Mandatory = $false, ValueFromPipeline = $true, ValueFromRemainingArguments = $true)]
        [object] 
        $Object,

        [Parameter()]
        [switch]
        $NoNewLine,

        [Parameter(Mandatory = $false)]
        [ConsoleColor]
        $ForegroundColor,

        [Parameter(Mandatory = $false)]
        [ConsoleColor]
        $BackgroundColor,
        
        [Parameter(Mandatory = $false)]
        [Object]
        $Separator
    )

    if ($null -ne $Boxstarter.ScriptToCall) { 
        Log-BoxStarterMessage $object 
    }

    if ($Boxstarter.SuppressLogging) {
        $caller = (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Name
        if ("Describe", "Context", "Write-PesterResult" -contains $caller) {
            Microsoft.PowerShell.Utility\Write-Host @PSBoundParameters
        }
        return;
    }
    $chocoWriteHost = Get-Command -Module chocolateyInstaller | Where-Object { $_.Name -eq "Write-Host" }

    if ($chocoWriteHost) {
        &($chocoWriteHost) @PSBoundParameters
    }
    else {
        Microsoft.PowerShell.Utility\Write-Host @PSBoundParameters
    }
}

new-alias Install-ChocolateyInstallPackage Install-ChocolateyInstallPackageOverride -force
new-alias Write-Host Write-HostOverride -force

<#
.SYNOPSIS
    Intercepts Chocolatey install call to check for reboots
    See function 'chocolatey' for more detail.
#>
function cinst {
    chocolatey -Command "Install" @args
}

<#
.SYNOPSIS
    Intercepts Chocolatey call to check for reboots
    See function 'chocolatey' for more detail.
#>
function choco {  
    param(
        [string]
        $Command
    )

    chocolatey -Command $Command @args
}

<#
.SYNOPSIS
    Intercepts Chocolatey upgrade call to check for reboots
    See function 'chocolatey' for more detail.
#>
function cup {
    chocolatey -Command "Upgrade" @args
}

<#
.SYNOPSIS
    Intercepts Chocolatey call to check for reboots

.DESCRIPTION
    This function wraps a Chocolatey command and provides additional features.
    - Enables the user to specify additonal RebootCodes
    - Detects pending reboots and restarts the machine when necessary to avoid installation failures
    - Provides Reboot Resiliency by ensuring the package installation is immediately restarted up on reboot if there is a reboot during the installation.

.PARAMETER Command
    The Chocolatey command to run.
    Only "install", "uninstall", "upgrade" and "update" will check for pending reboots.

.PARAMETER RebootCodes
    An array of additional return values that will yield in rebooting the machine if Chocolatey
    returns that value. These values will add to the default list of @(3010, -2067919934).
#>
function chocolatey {
    param(
        [string]
        $Command
    )

    $rebootProtectedCommands = @("install", "uninstall", "upgrade", "update")
    if ($rebootProtectedCommands -notcontains $command) {
        Call-Chocolatey @PSBoundParameters @args
        return
    }
    $argsExpanded = $args | Foreach-Object { "$($_); " }
    Write-BoxstarterMessage "Parameters to be passed to Chocolatey: Command='$Command', args='$argsExpanded'" -Verbose

    $stopOnFirstError = (Get-PassedSwitch -SwitchName "StopOnPackageFailure" -OriginalArgs $args) -Or $Boxstarter.StopOnPackageFailure
    Write-BoxstarterMessage "Will stop on first package error: $stopOnFirstError" -Verbose

    $rebootCodes = Get-PassedArg -ArgumentName 'RebootCodes' -OriginalArgs $args
    # if a 'pure Boxstarter' parameter has been specified, 
    # we need to remove it from the command line arguments that 
    # will be passed to Chocolatey, as only Boxstarter is able to handle it
    if ($null -ne $rebootCodes) {
        $argsWithoutBoxstarterSpecials = @()
        $skipNextArg = $false
        foreach ($a in $args) {
            if ($skipNextArg) {
                $skipNextArg = $false;
                continue;
            }

            if (@("-RebootCodes", "--RebootCodes") -contains $a) {
                $skipNextArg = $true
                continue;
            }
            if (@("-StopOnPackageFailure", "--StopOnPackageFailure" -contains $a)) {
                continue;
            }
            $argsWithoutBoxstarterSpecials += $a
        }
        $args = $argsWithoutBoxstarterSpecials
    }
    $rebootCodes = Add-DefaultRebootCodes -Codes $rebootCodes
    Write-BoxstarterMessage "RebootCodes: '$rebootCodes'" -Verbose

    $PackageNames = Get-PackageNamesFromInvocationLine -InvocationArguments $args
    $argsWithoutPackageNames = @()
    # we need to separate package names from remaining arguments,
    # as we're going to install packages one after another,
    # checking for required reboots in between the installs
    $args | ForEach-Object { 
        if ($PackageNames -notcontains $_) { 
            $argsWithoutPackageNames += $_
        } 
    }
    $args = $argsWithoutPackageNames
    Write-BoxstarterMessage "Installing $($PackageNames.Count) packages" -Verbose

    foreach ($packageName in $PackageNames) {
        $PSBoundParameters.PackageNames = $packageName
        if ((Get-PassedArg -ArgumentName @("source", "s") -OriginalArgs $args) -eq "WindowsFeatures") {
            $dismInfo = (DISM /Online /Get-FeatureInfo /FeatureName:$packageName)
            if ($dismInfo -contains "State : Enabled" -or $dismInfo -contains "State : Enable Pending") {
                Write-BoxstarterMessage "$packageName is already installed"
                return
            }
        }
        if (((Test-PendingReboot) -or $Boxstarter.IsRebooting) -and $Boxstarter.RebootOk) {
            return Invoke-Reboot
        }
        $session = Start-TimedSection "Calling Chocolatey to install $packageName. This may take several minutes to complete..."
        $currentErrorCount = 0
        $rebootable = $false
        try {
            [System.Environment]::ExitCode = 0
            Call-Chocolatey -Command $Command -PackageNames $PackageNames @args
            $ec = [System.Environment]::ExitCode
            # suppress errors from enabled features that need a reboot
            if ((Test-WindowsFeatureInstall $args) -and $ec -eq 3010) { 
                $ec = 0
            }
            # Chocolatey reassembles environment variables after an install
            # but does not add the machine PSModule value to the user Online
            $machineModPath = [System.Environment]::GetEnvironmentVariable("PSModulePath", "Machine")
            if (!$env:PSModulePath.EndsWith($machineModPath)) {
                $env:PSModulePath += ";" + $machineModPath
            }

            Write-BoxstarterMessage "Exit Code: $ec" -Verbose
            if ($ec -ne 0) {
                Write-Error "Chocolatey reported an unsuccessful exit code of $ec. See $($Boxstarter.Log) for details."
                $currentErrorCount += 1
            }
        }
        catch {
            #Only write the error to the error stream if it was not previously
            #written by Chocolatey
            $chocoErrors = $currentErrorCount
            if ($chocoErrors -gt 0) {
                $idx = 0
                $errorWritten = $false
                while ($idx -lt $chocoErrors) {
                    if (($global:error[$idx].Exception.Message | Out-String).Contains($_.Exception.Message)) {
                        $errorWritten = $true
                    }
                    if (!$errorWritten) {
                        Write-Error $_
                    }
                    $idx += 1
                }
            }
        }
        $chocoErrors = $currentErrorCount
        if ($chocoErrors -gt 0) {
            Write-BoxstarterMessage "There was an error calling Chocolatey" -Verbose
            $idx = 0
            while ($idx -lt $chocoErrors) {
                Write-BoxstarterMessage "Error from Chocolatey: $($global:error[$idx].Exception | fl * -Force | Out-String)"
                if ($global:error[$idx] -match "code (was '(?'ecwas'-?\d+)'|of (?'ecof'-?\d+)\.)") {
                    if ($matches["ecwas"]) {
                        $errorCode = $matches["ecwas"]
                    }
                    else {
                        $errorCode = $matches["ecof"]
                    }
                    if ($RebootCodes -contains $errorCode) {
                        Write-BoxstarterMessage "Chocolatey install returned a rebootable exit code ($errorCode)" -Verbose
                        $rebootable = $true
                    }
                    else {
                        Write-BoxstarterMessage "Exit Code '$errorCode' is no reason to reboot" -Verbose 
                        if ($stopOnFirstError) {
                            Write-BoxstarterMessage "Exiting because 'StopOnPackageFailure' is set."
                            Stop-Timedsection $session
                            Remove-ChocolateyPackageInProgress $packageName
                            exit 1
                        }
                    }
                }
                $idx += 1
            }
        }
        Stop-Timedsection $session
        if ($Boxstarter.IsRebooting -or $rebootable) {
            Remove-ChocolateyPackageInProgress $packageName
            Invoke-Reboot
        }
    }
}

<#
.SYNOPSIS
check if a parameter/switch is present in a list of arguments
(1-to many dashes followed by the parameter name)

#>
function Get-PassedSwitch {
    [CmdletBinding()]
    param(
        # the name of the argument switch to look for in $OriginalArgs
        [Parameter(Mandatory = $True)]
        [string]$SwitchName,

        # the full list of original parameters (probably $args)
        [Parameter(Mandatory = $False)]
        [string[]]$OriginalArgs
    )
    return [bool]($OriginalArgs | Where-Object { $_ -match "^-+$SwitchName$" })
}

<#
.SYNOPSIS
    Guess what parts of a choco invocation line are package names.
    (capture everything but named parameters and swtiches)
.EXAMPLE
    PS C:\> Get-PackageNamesFromInvocationLine @("-y", "foo", "bar", "-source", "https://myserver.org/choco")
    will
        * ignore '-y' (as it's not in the known named parameter set)
        * accept "foo" as first package name
        * accept "bar" as second package name
        * ignore '-source' as it's a known named parameter and therefore also skip 'https://myserver.org.choco'
    finally returning @("foo", "bar")
#>
function Get-PackageNamesFromInvocationLine {
    [CmdletBinding()]
    param(
        [PSObject[]]
        $InvocationArguments
    )

    $packageNames = @()

    # NOTE: whenever a new named parameter is added to chocolatey, make sure to update this list ...
    # we somehow need to know what parameters are named and can take a value
    # - if we don't know, the parameter's value will be treated as package name
    $namedParameters = @("force:", # -force:$bool is a zebra
        "s", "source",  
        "ia", "installargs", "installarguments", 
        "params", "parameters", "pkgparameters", "packageparameters", 
        "cp", 
        "checksum", "downloadchecksum", "checksum64", "checksumx64", "downloadchecksumx64",
        "checksumtype", "checksum-type", "downloadchecksumtyp",
        "checksumtype64", "checksumtypex64", "checksum-type-x64", "downloadchecksumtypex64")

    $skipNext = $false
    foreach ($a in $InvocationArguments) {
        if ($skipNext) {
            # the last thing we've seen is a named parameter
            # skip it's value and continue
            $skipNext = $false
            continue
        }

        # we try to match anything starting with dashes, 
        # as it will always be a parameter or switch
        # (and thus is not a package name)
        if ($a -match "^-.+") {
            $param = $a -replace "^-+"
            if ($namedParameters -contains $param) {
                $skipNext = $true
            }
        }
        else {
            $packageNames += $a
        }
    }
    $packageNames
}

function Get-PassedArg {
    [CmdletBinding()]
    param(
        [string[]]
        $ArgumentName,

        [string[]]
        $OriginalArgs
    )

    $candidateKeys = @()
    $ArgumentName | Foreach-Object {
        $candidateKeys += "-$_"
        $candidateKeys += "--$_"
    }
    $nextIsValue = $false
    $val = $null

    $OriginalArgs | Foreach-Object {
        if ($nextIsValue) {
            $nextIsValue = $false
            $val = $_
            return
        }

        if ($candidateKeys -contains $_) {
            $nextIsValue = $true
        }
        elseif ($_.ToString().Contains("=")) {
            $parts = $_.split("=", 2)
            $nextIsValue = $false
            $val = $parts[1]
        }
    }

    return $val
}

function Test-WindowsFeatureInstall($passedArgs) {
    (Get-PassedArg -ArgumentName @("source", "s") -OriginalArgs $passedArgs) -eq "WindowsFeatures"
}

function Call-Chocolatey {
    param(
        [string]
        $Command,

        [string[]]
        $PackageNames = @('')
    )

    $chocoArgs = @($Command, $PackageNames)
    $chocoArgs += Format-ExeArgs -Command $Command @args
    $chocoArgsExpanded = $chocoArgs | Foreach-Object { "$($_); " }
    Write-BoxstarterMessage "Passing the following args to Chocolatey: @($chocoArgsExpanded)" -Verbose

    $currentLogging = $Boxstarter.Suppresslogging
    try {
        if (Test-WindowsFeatureInstall $args) { 
            $Boxstarter.SuppressLogging = $true 
        }
        if (($PSVersionTable.CLRVersion.Major -lt 4 -or (Test-WindowsFeatureInstall $args)) -and (Get-IsRemote)) {
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
    if (Test-Path $restartFile) {
        Write-BoxstarterMessage "found $restartFile we are restarting"
        $Boxstarter.IsRebooting = $true
        remove-item $restartFile -Force
    }
}

function Invoke-ChocolateyFromTask($chocoArgs) {
    Invoke-BoxstarterFromTask "Invoke-Chocolatey $(Serialize-Array $chocoArgs)"
}

function Invoke-LocalChocolatey($chocoArgs) {
    if (Get-IsRemote) {
        $global:Boxstarter.DisableRestart = $true
    }
    Export-BoxstarterVars

    Enter-DotNet4 {
        if ($env:BoxstarterVerbose -eq 'true') {
            $global:VerbosePreference = "Continue"
        }

        Import-Module "$($args[1].BaseDir)\Boxstarter.chocolatey\Boxstarter.chocolatey.psd1" -DisableNameChecking
        Invoke-Chocolatey $args[0]
    } $chocoArgs, $Boxstarter
}

function Format-ExeArgs {
    param(
        [string]
        $Command
    )

    $newArgs = @()
    $args | ForEach-Object {
        $p = [string]$_
        if ($p -eq "-force: True") {
            $p = "-f"
        }
        elseif ($p -eq "-force: False") {
            return
        }
        elseif ($p.StartsWith("-") -and $p.Contains("=")) {
            $pts = $p.split("=", 2)
            $newArgs += $pts[0]
            $p = $pts[1]
        }

        $newArgs += $p
    }

    if ($null -eq (Get-PassedArg -ArgumentName @("source", "s") -OriginalArgs $args)) {
        if (@("Install", "Upgrade") -contains $Command) {
            $newArgs += "-Source"
            $newArgs += "$($Boxstarter.LocalRepo);$((Get-BoxstarterConfig).NugetSources)"
        }
    }

    if ($newArgs -notcontains "-Verbose") {
        if ($global:VerbosePreference -eq "Continue") {
            $newArgs += "-Verbose"
        }
    }

    if ($newArgs -notcontains "-y") {
        $newArgs += '-y'
    }
    $newArgs
}

function Add-DefaultRebootCodes {
    [CmdletBinding()]
    param(
        [PSObject[]]
        $Codes
    )

    if ($Codes -notcontains 3010) {
        $Codes += 3010 #common MSI reboot needed code
    }
    if ($Codes -notcontains -2067919934) {
        $Codes += -2067919934 #returned by SQL Server when it needs a reboot
    }
    return $Codes
}

function Remove-ChocolateyPackageInProgress($packageName) {
    $pkgDir = "$env:ChocolateyInstall\lib\$packageName"
    if (Test-Path $pkgDir) {
        Write-BoxstarterMessage "Removing $pkgDir in progress" -Verbose
        remove-item $pkgDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Expand-Splat($splat) {
    $ret = ""
    ForEach ($item in $splat.KEYS.GetEnumerator()) {
        $ret += "-$item$(Resolve-SplatValue $splat[$item]) "
    }
    Write-BoxstarterMessage "Expanded splat to $ret"
    return $ret
}

function Resolve-SplatValue($val) {
    if ($val -is [switch]) {
        if ($val.IsPresent) {
            return ":`$True"
        }
        else {
            return ":`$False"
        }
    }
    return " $(ConvertTo-PSString $val)"
}

function Wait-ForMSIEXEC {
    Write-BoxstarterMessage "Checking for other running MSIEXEC installers..." -Verbose
    Do {
        Get-Process | Where-Object { $_.Name -eq "MSIEXEC" } | Foreach-Object {
            if (!($_.HasExited)) {
                $proc = Get-WmiObject -Class Win32_Process -Filter "ProcessID=$($_.Id)"
                if ($null -ne $proc.CommandLine -and $proc.CommandLine.EndsWith(" /V")) { 
                    break 
                }
                Write-BoxstarterMessage "Another installer is running: $($proc.CommandLine). Waiting for it to complete..."
                $_.WaitForExit()
            }
        }
    } Until ($null -eq (Get-Process | Where-Object { $_.Name -eq "MSIEXEC" } ))
}

function Export-BoxstarterVars {
    $boxstarter.keys | ForEach-Object {
        Export-ToEnvironment "Boxstarter.$_"
    }
    if ($script:BoxstarterPassword) {
        Export-ToEnvironment "BoxstarterPassword" script
    }
    Export-ToEnvironment "VerbosePreference" global
    Export-ToEnvironment "DebugPreference" global
    $env:BoxstarterSourcePID = $PID
}

function Export-ToEnvironment($varToExport, $scope) {
    $val = Invoke-Expression "`$$($scope):$varToExport"
    if ($val -is [string] -or $val -is [boolean]) {
        Set-Item -Path "Env:\BEX.$varToExport" -Value $val.ToString() -Force
    }
    elseif ($null -eq $val) {
        Set-Item -Path "Env:\BEX.$varToExport" -Value '$null' -Force
    }
    Write-BoxstarterMessage "Exported $varToExport from $PID to `$env:BEX.$varToExport with value $val" -verbose
}

function Serialize-BoxstarterVars {
    $res = ""
    $boxstarter.keys | Foreach-Object {
        $res += "`$global:Boxstarter['$_']=$(ConvertTo-PSString $Boxstarter[$_])`r`n"
    }
    if ($script:BoxstarterPassword) {
        $res += "`$script:BoxstarterPassword='$($script:BoxstarterPassword)'`r`n"
    }
    $res += "`$global:VerbosePreference='$global:VerbosePreference'`r`n"
    $res += "`$global:DebugPreference='$global:DebugPreference'`r`n"
    Write-BoxstarterMessage "Serialized boxstarter vars to:" -verbose
    Write-BoxstarterMessage $res -verbose
    $res
}

function Import-FromEnvironment ($varToImport, $scope) {
    if (!(Test-Path "Env:\$varToImport")) { 
        return 
    }
    [object]$ival = (Get-Item "Env:\$varToImport").Value.ToString()

    if ($ival.ToString() -eq 'True') { 
        $ival = $true 
    }
    if ($ival.ToString() -eq 'False') {
        $ival = $false 
    }
    if ($ival.ToString() -eq '$null') {
        $ival = $null 
    }

    Write-BoxstarterMessage "Importing $varToImport from $env:BoxstarterSourcePID to $PID with value $ival" -Verbose

    $newVar = $varToImport.Substring('BEX.'.Length)
    Invoke-Expression "`$$($scope):$newVar=$(ConvertTo-PSString $ival)"

    remove-item "Env:\$varToImport"
}

function Import-BoxstarterVars {
    Write-BoxstarterMessage "Importing Boxstarter vars into pid $PID from pid: $($env:BoxstarterSourcePID)" -verbose
    Import-FromEnvironment "BEX.BoxstarterPassword" script

    $varsToImport = @()
    Get-ChildItem -Path env: | Where-Object { $_.Name.StartsWith('BEX.') } | ForEach-Object { $varsToImport += $_.Name }

    $varsToImport | ForEach-Object { Import-FromEnvironment $_ global }

    $boxstarter.SourcePID = $env:BoxstarterSourcePID
}

function ConvertTo-PSString($originalValue) {
    if ($originalValue -is [int] -or $originalValue -is [int64]) {
        "$originalValue"
    }
    elseif ($originalValue -is [Array]) {
        Serialize-Array $originalValue
    }
    elseif ($originalValue -is [boolean]) {
        "`$$($originalValue.ToString())"
    }
    elseif ($null -ne $originalValue) {
        "`"$($originalValue.ToString().Replace('"','`' + '"'))`""
    }
    else {
        "`$null"
    }
}

function Serialize-Array($chocoArgs) {
    $first = $false
    $res = "@("
    $chocoArgs | Foreach-Object {
        if ($first) { 
            $res += "," 
        }
        $res += ConvertTo-PSString $_
        $first = $true
    }
    $res += ")"
    $res
}
