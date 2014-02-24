function Set-BoxstarterPackageNugetFeed {
    [CmdletBinding()]
    param (
        [string]$PackageName,
        [Uri]$NugetFeed
    )
    if(!(Test-Path "$($Boxstarter.LocalRepo)\$PackageName")) {
        throw New-Object -TypeName InvalidOperationException -ArgumentList "The $PackageName package could not be found. There is no directory $($Boxstarter.LocalRepo)\$PackageName"
    }

    $path=Get-PackageFeedsPath
    if(!(Test-Path $path)) { 
        $feeds =  @{}
    }
    else {
        $feeds = Import-CliXML $path
    }

    $feeds.$PackageName = $NugetFeed
    $feeds | Export-CliXML ($path)
}