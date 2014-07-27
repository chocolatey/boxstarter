function Get-IsRemote {
param (
    [switch]$PowershellRemoting
)
<#
.SYNOPSIS
Returns $True if the current PowerShell session is running remotely

.LINK
http://boxstarter.codeplex.com

#>    
    if($PSSenderInfo -ne $null) {return $true}
    if($PowershellRemoting) {return $false}
    if($env:IsRemote -ne $null) { return [bool]::Parse($env:IsRemote) }
    else {
        $env:IsRemote = Test-ChildOfWinrs
        return [bool]::Parse($env:IsRemote)
    }
}

function Test-ChildOfWinrs($ID = $PID) {
   $parent = (Get-WmiObject -Class Win32_Process -Filter "ProcessID=$ID").ParentProcessID 
    if($parent -eq $null) { return $false } else {
    	try {$parentProc = Get-Process -ID $parent -ErrorAction Stop} catch {
            $global:error.RemoveAt(0)
            return $false
        }
    	if($parentProc.Name -eq "winrshost.exe") {return $true} 
        elseif($parentProc.Name -eq "services.exe") {return $false} 
    	else {
    		return Test-ChildOfWinrs $parent
    	}
    }
} 