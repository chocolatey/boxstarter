function Get-IsRemote {
<#
.SYNOPSIS
Returns $True if the current Powershell session is running remotely

.LINK
http://boxstarter.codeplex.com

#>    
    $res =  $PSSenderInfo -ne $null
	return $res
}