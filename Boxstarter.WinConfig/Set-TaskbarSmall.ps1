function Set-TaskbarSmall {
<#
.SYNOPSIS
Makes the windows task bar skinny
#>
	Write-Warning "This command is deprecated, use Set-BoxstarterTaskbarOptions instead."
	Write-Warning "Your call to this function will now be routed to the Set-BoxstarterTaskbarOptions function."

    Set-BoxstarterTaskbarOptions -Size Small
}
