function Get-BoxstarterFeedAPIKey {
    [CmdletBinding()]
    param (
        [URI]$NugetFeed
    )

    $path=Get-FeedsAPIKeyPath
    if(!(Test-Path $path)) { 
        $keys =  @{}
    }
    else {
        $keys = Import-CliXML $path
    }

    if($NugetFeed -and $keys.ContainsKey($NugetFeed)) {
        return $keys.$NugetFeed
    }
}