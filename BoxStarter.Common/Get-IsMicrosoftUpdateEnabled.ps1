function Get-IsMicrosoftUpdateEnabled {
<#
.SYNOPSIS
Returns $True if Microsoft Update is currently enabled

.LINK
https://boxstarter.org

#>
	# Default response to false, unless proven otherwise
	$installed = $false

	$serviceManager = New-Object -ComObject Microsoft.Update.ServiceManager -Strict
	$serviceManager.ClientApplicationID = "Boxstarter"

	foreach ($service in $serviceManager.Services) {
		if( $service.Name -eq "Microsoft Update") {
			$installed = $true;
			break;
		}
	}

	return $installed
}
