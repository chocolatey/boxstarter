function Test-Admin {
<#
.SYNOPSIS
Determines if the console is elevated

#>
    if ($PSVersionTable.Platform -ne 'Windows') {
        # no windows, no worries
        return $true
    }

    $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal( $identity )
    return $principal.IsInRole( [System.Security.Principal.WindowsBuiltInRole]::Administrator )
}

