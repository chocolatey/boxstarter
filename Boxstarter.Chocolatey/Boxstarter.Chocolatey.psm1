param(
    [parameter(Position=0,Mandatory=$false)][boolean]$ExportCommands=$false
)
$unNormalized=(Get-Item "$PSScriptRoot\..\Boxstarter.Bootstrapper\Boxstarter.Bootstrapper.psd1")
Import-Module $unNormalized.FullName -global -DisableNameChecking -Force
Resolve-Path $PSScriptRoot\*.ps1 | 
    % { . $_.ProviderPath }

if($ExportCommands) { 
    Import-BoxstarterVars
    Export-ModuleMember cinst, cup, choco 
}

Export-ModuleMember Invoke-ChocolateyBoxstarter, New-BoxstarterPackage, Invoke-BoxstarterBuild, Get-PackageRoot, Set-BoxstarterShare, Get-BoxstarterConfig, Set-BoxstarterConfig, Install-BoxstarterPackage, New-PackageFromScript, Enable-BoxstarterClientRemoting, Enable-BoxstarterCredSSP, Resolve-VMPlugin, Register-ChocolateyInterception, Invoke-Chocolatey

Export-ModuleMember Install-ChocolateyInstallPackageOverride,
                    Write-HostOverride
Export-ModuleMember -alias Install-ChocolateyInstallPackage, Write-Host, Enable-BoxstarterVM