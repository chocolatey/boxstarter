function Get-IsRemote {
	return $PSSenderInfo -ne $null
}