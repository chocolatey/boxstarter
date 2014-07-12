function Get-IsRemote {
<#
.SYNOPSIS
Returns $True if the current PowerShell session is running remotely

.LINK
http://boxstarter.codeplex.com

#>    
    if($PSSenderInfo -ne $null) {return $true}
    else {
        return Test-ChildOfWinrs
    }
}

function Test-ChildOfWinrs($ID = $PID) {
   $parent = (Get-WmiObject -Class Win32_Process -Filter "ProcessID=$ID").ParentProcessID 
    if($parent -eq $null) { return $false } else {
    	$parentProc = Get-WmiObject -Class Win32_Process -Filter "ProcessID=$parent"
    	if($parentProc.Name -eq "winrshost.exe") {return $true} 
        elseif($parentProc.Name -eq "services.exe") {return $false} 
    	else {
    		return Test-ChildOfWinrs $parent
    	}
    }
} 