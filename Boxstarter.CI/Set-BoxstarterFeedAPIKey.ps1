function Set-BoxstarterFeedAPIKey {
    [CmdletBinding()]
    param (
        [Uri]$NugetFeed,
        [GUID]$APIKey
    )
    $path=Get-FeedsAPIKeyPath
    if(!(Test-Path $path)) { 
        $keys =  @{}
    }
    else {
        $keys = Import-CliXML $path
    }

    $keys[$NugetFeed] = $APIKey
    $keys | Export-CliXML ($path)
}