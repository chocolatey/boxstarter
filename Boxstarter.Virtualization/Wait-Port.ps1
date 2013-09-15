function Wait-Port {
	param(
		[string]$hostName,
		[int]$Port,
		[int]$timeout = 30000

	)
	$s = [System.Diagnostics.Stopwatch]::StartNew()
	$t = New-Object Net.Sockets.TcpClient
	try{
		while($s.ElapsedMilliseconds -le $Timeout) {
			try{
				$t.Connect($hostName,$Port)
				if($t.Connected)
				{
				    return $true
				}
			}
			catch [System.Net.Sockets.SocketException]{
				start-sleep -milliseconds 100
			}
		}
	}
	finally{
		if($t -ne $null){
			$t.Dispose()
		}
	}
	return $false
}