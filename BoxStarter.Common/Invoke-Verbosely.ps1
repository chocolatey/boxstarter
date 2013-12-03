function Invoke-Verbosely{
<#
.SYNOPSIS
Ensures that the script and all commands it calls are 
executed with the VerbosityPreference set to Continue 
if the -Verbose common parameter is $true

.PARAMETER ScriptToInvoke
The script to execute.

.EXAMPLE
Invoke-Remotely -Verbose:($PSBoundParabeers['Verbose'] -eq $true) {
    Write-BoxstarterMessage "this is verbose" -Verbose
}

If Verbose is true, "this is verbose" will be written t othe verbose stream"

.LINK
http://boxstarter.codeplex.com

#>
    [CmdletBinding()]
    param(
        [ScriptBlock]$ScriptToInvoke
    )
    $CurrentVerbosity=$global:VerbosePreference
    try {
        if($PSBoundParameters["Verbose"] -eq $true) {
            $global:VerbosePreference="Continue"
        }
        Invoke-Command $scriptToInvoke
    }
    finally{
        $global:VerbosePreference=$CurrentVerbosity
    }

}