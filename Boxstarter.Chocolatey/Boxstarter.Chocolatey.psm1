$unNormalized=(Get-Item "$PSScriptRoot\..\Boxstarter.Bootstrapper\Boxstarter.Bootstrapper.psd1")
Import-Module $unNormalized.FullName -global -DisableNameChecking
Resolve-Path $PSScriptRoot\*.ps1 | 
    % { . $_.ProviderPath }
[xml]$configXml = Get-Content (Join-Path $Boxstarter.BaseDir BoxStarter.config)
$Boxstarter.Config = $configXml.config
Export-ModuleMember Invoke-ChocolateyBoxstarter, cinst, cup, cinstm, chocolatey, New-BoxstarterPackage, Invoke-BoxstarterBuild, Get-PackageRoot, Set-BoxstarterShare