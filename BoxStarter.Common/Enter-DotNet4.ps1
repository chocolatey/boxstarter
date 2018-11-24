function Enter-Dotnet4 {
<#
.SYNOPSIS
Runs a script from a process hosting the .net 4 runtime

.DESCRIPTION
This function will ensure that the .net 4 runtime is installed on the
machine. If it is not, it will be downloaded and installed. If running
remotely, the .net 4 installation will run from a scheduled task.

If the CLRVersion of the hosting PowerShell process is less than 4,
such as is the case in PowerShell 2, the given script will be run
from a new a new PowerShell process tht will be configured to host the
CLRVersion 4.0.30319.

.Parameter ScriptBlock
The script to be executed in the .net 4 CLR

.Parameter ArgumentList
Arguments to be passed to the ScriptBlock

.LINK
https://boxstarter.org

#>
    param(
        [ScriptBlock]$ScriptBlock,
        [object[]]$ArgumentList
    )
    Enable-Net40
    if($PSVersionTable.CLRVersion.Major -lt 4) {
        Write-BoxstarterMessage "Relaunching PowerShell under .net fx v4" -verbose
        $env:COMPLUS_version="v4.0.30319"
        & powershell -OutputFormat Text -NoProfile -ExecutionPolicy bypass -command $ScriptBlock -args $ArgumentList
    }
    else {
        Write-BoxstarterMessage "Using current PowerShell..." -verbose
        Invoke-Command -ScriptBlock $ScriptBlock -argumentlist $ArgumentList
    }
}

function Is64Bit {  [IntPtr]::Size -eq 8  }

function Enable-Net40 {
    if(Is64Bit) {$fx="framework64"} else {$fx="framework"}
    if(!(test-path "$env:windir\Microsoft.Net\$fx\v4.0.30319")) {
        if((Test-PendingReboot) -and $Boxstarter.RebootOk) {return Invoke-Reboot}
        Write-BoxstarterMessage "Downloading .net 4.5..."
        Get-HttpResource "https://download.microsoft.com/download/b/a/4/ba4a7e71-2906-4b2d-a0e1-80cf16844f5f/dotnetfx45_full_x86_x64.exe" "$env:temp\net45.exe"
        Write-BoxstarterMessage "Installing .net 4.5..."
        if(Get-IsRemote) {
            Invoke-FromTask @"
Start-Process "$env:temp\net45.exe" -verb runas -wait -argumentList "/quiet /norestart /log $env:temp\net45.log"
"@
        }
        else {
            $proc = Start-Process "$env:temp\net45.exe" -verb runas -argumentList "/quiet /norestart /log $env:temp\net45.log" -PassThru
            while(!$proc.HasExited){ sleep -Seconds 1 }
        }
    }
}
