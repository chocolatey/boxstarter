function Get-IsRemote {
param (
    [switch]$PowershellRemoting
)
<#
.SYNOPSIS
Returns $True if the current PowerShell session is running remotely

.LINK
https://boxstarter.org

#>
    if($PSSenderInfo -ne $null) {return $true}
    if($PowershellRemoting) {return $false}
    if($env:IsRemote -ne $null) { return [bool]::Parse($env:IsRemote) }
    else {
        $script:recursionLevel = 0
        $env:IsRemote = Test-ChildOfWinrs
        return [bool]::Parse($env:IsRemote)
    }
}

function Test-ChildOfWinrs($ID = $PID) {
   if(++$script:recursionLevel -gt 20) { return $false }
   $parent = (Get-WmiObject -Class Win32_Process -Filter "ProcessID=$ID").ParentProcessID
    if($parent -eq $null) {
        Log-BoxstarterMessage "No parent process found. Must be root."
        return $false
    }
    else {
    	try {$parentProc = Get-Process -ID $parent -ErrorAction Stop} catch {
            Log-BoxstarterMessage "Error getting parent process"
            $global:error.RemoveAt(0)
            return $false
        }
        Log-BoxstarterMessage "parent process is $($parentProc.Name)"

        if(@('wsmprovhost','winrshost') -Contains $parentProc.Name) {return $true}
        elseif($parentProc.Name -eq "services") {return $false}
    	else {
    		return Test-ChildOfWinrs $parent
    	}
    }
}
