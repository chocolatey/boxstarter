function Export-TaskbarOptions {
<#
.SYNOPSIS
Exports options for the Windows Task Bar

.LINK
http://boxstarter.org
#>

	$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
	$dockingKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects2'

	Write-BoxstarterMessage "Exporting Windows Task Bar options..."

	$args = @()
	if(Test-Path -Path $key) {
		$args += switch ((Get-ItemProperty $key).TaskbarSizeMove) 
                 { 0 {"Lock"} 
                   1 {"UnLock"} }		
		$args += switch ((Get-ItemProperty $key).TaskbarSmallIcons) 
                 { 0 {"Size Large"} 
                   1 {"Size Small"} }		
	}	

    # The actual value for the position is encoded in 12th index of the Settings array
    # Values:
    # 0x00 = Left
    # 0x01 = Top
    # 0x02 = Right
    # 0x03 = Bottom
    $magicValue = 12
	if(Test-Path -Path $dockingKey) {
		$args += switch ((Get-ItemProperty $dockingKey).Settings[$magicValue]) 
                 { 0x00 {"Dock Left"}
                   0x01 {"Dock Top"}
                   0x02 {"Dock Right"}
                   0x03 {"Dock Bottom"} }
	}

	[PSCustomObject]@{"Command" = "Set-TaskbarOptions"; "Arguments" = $args}
}