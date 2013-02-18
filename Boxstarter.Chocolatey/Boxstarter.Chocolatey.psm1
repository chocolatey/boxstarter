Resolve-Path $PSScriptRoot\*.ps1 | 
    % { . $_.ProviderPath }

Export-ModuleMember Invoke-ChocolateyBoxstarter, cinst, cup, cinstm, chocolatey
get-command -Module Boxstarter.Bootstrapper | ?{ $_.name -ne "Invoke-Boxstarter"} | %{ $_.name } | Export-ModuleMember

