function Get-CurrentUser {
<#
.SYNOPSIS
Returns the domain and username of the currently logged in user.

#>
    $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $parts = $identity.Name -split "\\"
    return @{Domain=$parts[0];Name=$parts[1]}
}
