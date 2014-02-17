function Set-TaskbarSmall {
<#
.SYNOPSIS
Makes the windows task bar skinny
#>
	Write-Warning "This command is deprecated, use Set-TaskbarOptions instead."
	Write-Warning "Your call to this function will now be routed to the Set-TaskbarOptions function."

    Set-TaskbarOptions -Size Small
}
