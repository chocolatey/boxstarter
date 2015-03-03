catch$unNormalized=(Get-Item "$PSScriptRoot\..\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1")
Import-Module $unNormalized.FullName -global -DisableNameChecking -Force
Resolve-Path $PSScriptRoot\*-*.ps1 | 
    % { . $_.ProviderPath }

#There is a bug where the storage module will not load if loaded after the azure module
try {Get-Module Storage -ListAvailable | Import-Module -global} catch { Log-BoxstarterMessage $_ }

Import-AzureModule

Export-ModuleMember Enable-BoxstarterVM, Get-AzureVMCheckpoint, Set-AzureVMCheckpoint, Restore-AzureVMCheckpoint, Remove-AzureVMCheckpoint, Test-VMStarted