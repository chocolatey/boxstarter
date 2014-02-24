function Remove-BoxstarterPackageNugetFeed {
    [CmdletBinding()]
    param (
        [string]$packageName
    )
    $path=Get-PackageFeedsPath
    if(!(Test-Path $path)) { 
        $feeds =  @{}
    }
    else {
        $feeds = Import-CliXML $path
    }

    $feeds.Remove($packageName)
    $feeds | Export-CliXML ($path)
}