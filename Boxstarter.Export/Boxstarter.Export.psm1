Resolve-Path $PSScriptRoot\*.ps1 | 
    % { . $_.ProviderPath }

Export-ModuleMember Export-WindowsExplorerOptions