function Set-DesktopOptions {
<#
.SYNOPSIS
Sets options for the Windows Task Bar

.PARAMETER Hide
Hides Desktop Icons

.PARAMETER Show
Shows Desktop Icons

.PARAMETER IconTitles
Shows or Hides Icon Titles


#>
	[CmdletBinding(DefaultParameterSetName='hide')]
	param(
        [Parameter(ParameterSetName='show')]
        [switch]$Show,
        [Parameter(ParameterSetName='hide')]
        [switch]$Hide,
		[ValidateSet('On','Off')]
		$IconTitles
	)

	$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

	if(Test-Path -Path $key) {
		if($Show) 
		{ 
			Set-ItemProperty $key HideIcons 0
        }
        if($Hide){
			Set-ItemProperty $key HideIcons 1 
		} 

		switch ($IconTitles) {
			"Off" { Set-ItemProperty $key IconsOnly 1 }
			"On" { Set-ItemProperty $key IconsOnly 0 }
		}

		Restart-Explorer
	}	

}