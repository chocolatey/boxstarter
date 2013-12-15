function Disable-MicrosoftUpdate {
<#
.SYNOPSIS
Turns off Microsoft Update, so additional updates for other Microsoft products, installed on the system, will not be included when running Windows Update.

.LINK
http://boxstarter.codeplex.com
Enable-MicrosoftUpdate

#>
	Write-BoxstarterMessage "Disabling Microsoft Update"

	# Making modifications to removed an established Service, when being executed from a remote session, needs elevated permissions.
	# As a result, a call to invoke a scheduled task to execute the work will be used, otherwise execute normally.
    if(Get-IsRemote){
        Invoke-FromTask @"
			`$serviceManager = New-Object -ComObject Microsoft.Update.ServiceManager -Strict
			`$serviceManager.ClientApplicationID = "Boxstarter"
			`$serviceManager.RemoveService("7971f918-a847-4430-9279-4a52d1efe18d")
"@
    }
    else{
       $serviceManager = New-Object -ComObject Microsoft.Update.ServiceManager -Strict
       $serviceManager.ClientApplicationID = "Boxstarter"
       $serviceManager.RemoveService("7971f918-a847-4430-9279-4a52d1efe18d")
    }   
}