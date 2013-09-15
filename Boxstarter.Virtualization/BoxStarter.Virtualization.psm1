Resolve-Path $PSScriptRoot\*-*.ps1 | 
    % { . $_.ProviderPath }

Export-ModuleMember Add-VHDStartupScript,`
                    Install-BoxstarterVM,`
                    Remove-VHDStartupScript,`
                    Get-VHDComputerName,`
                    Enable-VMPSRemoting
                    
Export-ModuleMember -Variable Boxstarter
