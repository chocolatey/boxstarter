Resolve-Path $PSScriptRoot\*.ps1 |
    % { . $_.ProviderPath }

Export-ModuleMember Confirm-Choice,`
                    Create-BoxstarterTask,`
                    Enter-BoxstarterLogable,`
                    Enter-DotNet4,`
                    Get-CurrentUser,`
                    Get-HttpResource,`
                    Get-IsMicrosoftUpdateEnabled,`
                    Get-IsRemote,`
                    Invoke-FromTask,`
                    Invoke-RetriableScript,`
                    Out-BoxstarterLog,`
                    Log-BoxstarterMessage,`
                    Remove-BoxstarterError,`
                    Remove-BoxstarterTask,`
                    Start-TimedSection,`
                    Stop-TimedSection,`
                    Test-Admin,`
                    Write-BoxstarterLogo,`
                    Write-BoxstarterMessage

Export-ModuleMember -Variable Boxstarter
