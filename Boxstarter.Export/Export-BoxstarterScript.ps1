function Export-BoxstarterScript {
<#
.SYNOPSIS
Exports the current box configuration as a Boxstarter script

.DESCRIPTION

.PARAMETER OutputFileName
The name of the script to export

.PARAMETER All
Indicates that all settings should be exported

.LINK
http://boxstarter.org
#>

    [CmdletBinding()]
    param(
        [Parameter(Position=0,ParameterSetName='outputFileName')]
        [string]$outputFileName,
        [Parameter(Position=0,ParameterSetName='all')]
        [switch]$all,
        [switch]$quiet
    )

    $result = @()
    Get-Command -Module Boxstarter.Export| % {
        $obj = Invoke-Command $_
        
        $command = $obj.Command
        $args = $obj.Arguments

        if ($args -ne $null) {
            $args = ($obj.Arguments | % { "-" + $_ })
        }

        if ($command -ne $null) {
            if ($command.Count -gt 1) {
                $result += $command | % { $_ }
            } else {
                $result += $($obj.Command + " " + $args) | Write-Host
            }
        }
    }

    # TODO: write the result to file
    $result

}

Export-BoxstarterScript -outputFileName "foo"