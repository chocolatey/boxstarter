function Get-IsMicrosoftUpdateEnabled {
<#
.SYNOPSIS
Returns $True if Microsoft Update is currently enabled

.LINK
http://boxstarter.codeplex.com

#>    
	$installed = $false
	foreach ($service in $serviceManager.Services) {
		if( $service.Name -eq "Microsoft Update") {
			$installed = $true;  
			break;
		} 
	}
	
	return $installed
}