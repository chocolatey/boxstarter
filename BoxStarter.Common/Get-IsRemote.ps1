function Get-IsRemote {
<#
.SYNOPSIS
Returns $True if the current Powershell session is running remotely

.LINK
http://boxstarter.codeplex.com

#>    
	return $PSSenderInfo -ne $null
}