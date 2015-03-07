Resolve-Path $PSScriptRoot\*.ps1 | 
    % { . $_.ProviderPath }

Export-ModuleMember Export-CornerNavigationOptions, Export-InternetExplorerESC, Export-StartScreenOptions, Export-TaskbarOptions, Export-WindowsExplorerOptions