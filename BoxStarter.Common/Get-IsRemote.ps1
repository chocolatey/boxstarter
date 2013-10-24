function Get-IsRemote {
	return $PSSenderInfo.ApplicationArguments.RemoteBoxstarter -ne $null
}