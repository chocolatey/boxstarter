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
        $obj = & $_
        
        $command = $obj.Command
        $args = $obj.Arguments

        if ($args -ne $null) {
            $args = $args | % { $("-" + $_) }
        }

        if ($command -ne $null) {
            if ($command.Count -gt 1) {
                $result += $command | % { $_ }
            } else {
                $result += $($obj.Command + " " + $args)
            }
        }
    }

    
    if (Test-Path -Path $outputFileName) {
        if (-not (Confirm-Choice ("The file '" + $outputFileName + "' already exists. Do you want to overwrite it?"))) {
            Write-BoxstarterMessage ("Export cancelled!") -color Yellow
            return
        }
    }

    $result | Out-File $outputFileName
    Write-BoxstarterMessage ("Export completed! Your Boxstarter script is located at: '" + $outputFileName + "'")
}

Export-BoxstarterScript -outputFileName "D:\boxstarter.ps1"