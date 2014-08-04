$unNormalized=(Get-Item "$PSScriptRoot\..\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1")
Import-Module $unNormalized.FullName -global -DisableNameChecking -Force
Resolve-Path $PSScriptRoot\*-*.ps1 | 
    % { . $_.ProviderPath }

#There is a bug where the storage module will not load if loaded after the azure module
try {Get-Module Storage -ListAvailable | Import-Module -global} catch { Log-BoxstarterMessage $_ }

$azureMod = Get-Module Azure -ListAvailable
if(!$azureMod) {
    if(${env:ProgramFiles(x86)} -ne $null){ $programFiles86 = ${env:ProgramFiles(x86)} } else { $programFiles86 = $env:ProgramFiles }
    $modulePath="$programFiles86\Microsoft SDKs\Windows Azure\PowerShell\Azure\Azure.psd1"
    if(Test-Path $modulePath) {
        Import-Module $modulePath -global
    }
}
else {
    $azureMod | Import-Module -global
}
Export-ModuleMember Enable-BoxstarterVM, Get-AzureVMCheckpoint, Set-AzureVMCheckpoint, Restore-AzureVMCheckpoint, Remove-AzureVMCheckpoint, Test-VMStarted