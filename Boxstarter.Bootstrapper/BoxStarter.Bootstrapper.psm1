Resolve-Path $PSScriptRoot\*.ps1 | 
    % { . $_.ProviderPath }

[xml]$configXml = Get-Content "$PSScriptRoot\BoxStarter.config"
$Boxstarter = @{BaseDir=(Split-Path -parent $PSScriptRoot)}
$Boxstarter.Config = $configXml.config

Export-ModuleMember Invoke-BoxStarter, Test-PendingReboot, Invoke-Reboot, Write-BoxstarterMessage, Start-TimedSection, Stop-TimedSection
Export-ModuleMember -Variable Boxstarter
get-command -Module Boxstarter.WinConfig | %{ $_.name } | Export-ModuleMember
