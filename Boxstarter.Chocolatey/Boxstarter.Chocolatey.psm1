$unNormalized=(Get-Item "$PSScriptRoot\..\Boxstarter.Bootstrapper\Boxstarter.Bootstrapper.psd1")
Import-Module $unNormalized.FullName -global -DisableNameChecking
[xml]$configXml = Get-Content (Join-Path $Boxstarter.BaseDir BoxStarter.config)
$Boxstarter.Config = $configXml.config
Resolve-Path $PSScriptRoot\*.ps1 | 
    % { . $_.ProviderPath }
Export-ModuleMember Invoke-ChocolateyBoxstarter, New-BoxstarterPackage, Invoke-BoxstarterBuild, Get-PackageRoot, Set-BoxstarterShare