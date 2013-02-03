# Boxstarter
# Version: $version$
# Changeset: $sha$
Resolve-Path $PSScriptRoot\*.ps1 | 
    ? { -not ($_.ProviderPath.Contains("AdminProxy.ps1")) } |
    % { . $_.ProviderPath }

if(${env:ProgramFiles(x86)} -ne $null){ $programFiles86 = ${env:ProgramFiles(x86)} } else { $programFiles86 = $env:ProgramFiles }
[xml]$configXml = Get-Content "$PSScriptRoot\BoxStarter.config"
$baseDir = (Split-Path -parent $PSScriptRoot)
$config = $configXml.config

Export-ModuleMember Invoke-BoxStarter, Test-PendingReboot, Invoke-Reboot, cinst, cup, cinstm, chocolatey
Export-ModuleMember -Variable Boxstarter
