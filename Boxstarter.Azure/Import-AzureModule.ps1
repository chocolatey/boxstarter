function Import-AzureModule {
    $azureMod = Get-Module Azure -ListAvailable
    if(!$azureMod) {
        if(${env:ProgramFiles(x86)} -ne $null){ $programFiles86 = ${env:ProgramFiles(x86)} } else { $programFiles86 = $env:ProgramFiles }
        $modulePath="$programFiles86\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Azure.psd1"
        if(Test-Path $modulePath) {
            Import-Module $modulePath -global
        }
    }
    else {
        $azureMod | Import-Module -global
    }
}
