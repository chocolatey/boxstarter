$unNormalized=(Get-Item "$PSScriptRoot\..\Boxstarter.Bootstrapper\Boxstarter.Bootstrapper.psd1")
Import-Module $unNormalized.FullName -global -DisableNameChecking -Force
Resolve-Path $PSScriptRoot\*.ps1 | 
    % { . $_.ProviderPath }
Export-ModuleMember Invoke-ChocolateyBoxstarter, 
                    New-BoxstarterPackage, 
                    Invoke-BoxstarterBuild, 
                    Get-PackageRoot, 
                    Set-BoxstarterShare,
                    Get-BoxstarterConfig,
                    Set-BoxstarterConfig,
                    Install-BoxstarterPackage,
                    New-PackageFromScript

Export-ModuleMember Install-ChocolateyInstallPackageOverride,
                    Write-HostOverride
Export-ModuleMember -alias Install-ChocolateyInstallPackage,
                           Write-Host