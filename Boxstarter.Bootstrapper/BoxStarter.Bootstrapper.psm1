Resolve-Path $PSScriptRoot\*.ps1 | 
    % { . $_.ProviderPath }
$Boxstarter.BaseDir=(Split-Path -parent ((Get-Item $PSScriptRoot).FullName))
Import-Module (Join-Path $Boxstarter.BaseDir Boxstarter.WinConfig\BoxStarter.WinConfig.psd1) -global
[xml]$configXml = Get-Content (Join-Path $Boxstarter.BaseDir Boxstarter.Bootstrapper\BoxStarter.config)
$Boxstarter.Config = $configXml.config
Export-ModuleMember Invoke-BoxStarter, Test-PendingReboot, Invoke-Reboot, Write-BoxstarterMessage, Start-TimedSection, Stop-TimedSection
Export-ModuleMember -Variable Boxstarter
