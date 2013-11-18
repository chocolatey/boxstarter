function Update-ExecutionPolicy {
<#
.SYNOPSIS
Sets the execution policy for the current account

.DESCRIPTION
The execution policy is set in a separate elevated 
powershell process. If running in the chocolatey runner, 
the current window cannot be used because its execution 
policy has been explicitly set.

If on a 64 bit machine, the policy will be set for both 
64 and 32 bit shells.

.PARAMETER Policy
The execution policy to set

#>    
    param(
        [ValidateSet('Unrestricted','RemoteSigned','AllSigned','Restricted','Default','Bypass','Undefined')]
        [string]$policy
    )
    write-BoxstarterMessage "Setting powershell execution context to $policy"
    if(Is64Bit) {
        Start-Process "$env:SystemRoot\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" -verb runas -wait -argumentList "-noprofile -WindowStyle hidden -noninteractive -ExecutionPolicy unrestricted -Command `"Set-ExecutionPolicy $policy`""
    }
    Start-Process "powershell.exe" -verb runas -wait -argumentList "-noprofile -noninteractive -ExecutionPolicy unrestricted -WindowStyle hidden -Command `"Set-ExecutionPolicy $policy`""
}

function Is64Bit {  [IntPtr]::Size -eq 8  }
