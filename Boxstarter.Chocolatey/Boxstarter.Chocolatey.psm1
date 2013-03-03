Resolve-Path $PSScriptRoot\*.ps1 | 
    % { . $_.ProviderPath }
$unNormalized=(Get-Item "$PSScriptRoot\..\Boxstarter.Bootstrapper\Boxstarter.Bootstrapper.psd1")
Import-Module $unNormalized.FullName -global
Export-ModuleMember Invoke-ChocolateyBoxstarter, cinst, cup, cinstm, chocolatey