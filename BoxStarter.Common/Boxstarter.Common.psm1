Resolve-Path $PSScriptRoot\*.ps1 | 
    % { . $_.ProviderPath }

Export-ModuleMember Write-BoxstarterMessage, Start-TimedSection, Stop-TimedSection
