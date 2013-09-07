Resolve-Path $PSScriptRoot\*-*.ps1 | 
    % { . $_.ProviderPath }

Export-ModuleMember Add-VHDStartupScript, Install-BoxstarterVM, Remove-VHDStartupScript
Export-ModuleMember -Variable Boxstarter
