Resolve-Path $PSScriptRoot\*.ps1 |
    % { . $_.ProviderPath }

Import-Module (Join-Path $Boxstarter.BaseDir Boxstarter.WinConfig\BoxStarter.WinConfig.psd1) -global -DisableNameChecking

Export-ModuleMember Invoke-BoxStarter, `
                    Test-PendingReboot, `
                    Invoke-Reboot, `
                    Write-BoxstarterMessage, `
                    Start-TimedSection, `
                    Stop-TimedSection, `
                    Out-Boxstarter, `
                    Enter-BoxstarterLogable, `
                    Get-BoxstarterTempDir, `
                    Install-BoxstarterExtension
