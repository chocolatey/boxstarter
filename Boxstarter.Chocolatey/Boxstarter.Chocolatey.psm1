$unNormalized=(Get-Item "$PSScriptRoot\..\Boxstarter.Bootstrapper\Boxstarter.Bootstrapper.psd1")
Import-Module $unNormalized.FullName -global -DisableNameChecking
Resolve-Path $PSScriptRoot\*.ps1 | 
    % { . $_.ProviderPath }
Export-ModuleMember Invoke-ChocolateyBoxstarter, 
                    New-BoxstarterPackage, 
                    Invoke-BoxstarterBuild, 
                    Get-PackageRoot, 
                    Set-BoxstarterShare,
                    Get-BoxstarterConfig,
                    Set-BoxstarterConfig,
                    Install-BoxstarterPackage
                    New-PackageFromScript

Export-ModuleMember Install-ChocolateyInstallPackageOverride
Export-ModuleMember -alias Install-ChocolateyInstallPackage