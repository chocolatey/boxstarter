function Enable-MicrosoftUpdate {
<#
.SYNOPSIS
Turns on Microsoft Update, so additional updates for other Microsoft products, installed on the system, will be included when running Windows Update.

.LINK
http://boxstarter.codeplex.com
Disable-MicrsoftUpdate

#>
    Write-BoxstarterMessage "Enabling Microsoft Update"
    
	$serviceManager = New-Object -ComObject Microsoft.Update.ServiceManager -Strict
	$serviceManager.ClientApplicationID = "Boxstarter"
	$serviceManager.AddService2("7971f918-a847-4430-9279-4a52d1efe18d",7,"")
}