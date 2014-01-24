$unNormalized=(Get-Item "$PSScriptRoot\..\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1")
Import-Module $unNormalized.FullName -global -DisableNameChecking -Force
Resolve-Path $PSScriptRoot\*-*.ps1 | 
    % { . $_.ProviderPath }
if((Get-Module Azure -ListAvailable) -eq $null) {
    if(${env:ProgramFiles(x86)} -ne $null){ $programFiles86 = ${env:ProgramFiles(x86)} } else { $programFiles86 = $env:ProgramFiles }
    $modulePath="$programFiles86\Microsoft SDKs\Windows Azure\PowerShell\Azure\Azure.psd1"
    if(Test-Path $modulePath) {
        Import-Module $modulePath -global
    }
}
else {
    Import-Module Azure -global
}
Export-ModuleMember Enable-BoxstarterVM, Get-AzureVMCheckpoint, Set-AzureVMCheckpoint, Restore-AzureVMCheckpoint, Remove-AzureVMCheckpoint