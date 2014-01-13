$unNormalized=(Get-Item "$PSScriptRoot\..\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1")
Import-Module $unNormalized.FullName -global -DisableNameChecking -Force
Resolve-Path $PSScriptRoot\*-*.ps1 | 
    % { . $_.ProviderPath }

Export-ModuleMember Enable-BoxstarterVM, Get-AzureVMCheckpoint, Set-AzureVMCheckpoint, Restore-AzureVMCheckpoint, Remove-AzureVMCheckpoint