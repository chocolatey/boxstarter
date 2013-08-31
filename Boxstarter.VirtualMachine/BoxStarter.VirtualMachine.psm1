Resolve-Path $PSScriptRoot\*.ps1 | 
    % { . $_.ProviderPath }

Export-ModuleMember Add-VHDStartupScript, Install-BoxstarterVM
Export-ModuleMember -Variable Boxstarter
