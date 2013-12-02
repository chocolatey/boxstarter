function Wait-Port {
	param(
		[string]$hostName,
		[int]$Port,
		[int]$timeout = 30000

	)
    $passes = 0
	$s = [System.Diagnostics.Stopwatch]::StartNew()
	$t = New-Object Net.Sockets.TcpClient
	try{
		while($s.ElapsedMilliseconds -le $Timeout) {
			try{
				$t.Connect($hostName,$Port)
				if($t.Connected)
				{
				    $passes++
                    if($passes -ge 5){
                        return $true
                    }
                    $t.Dispose()
                    sleep 1
                    $t = New-Object Net.Sockets.TcpClient
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