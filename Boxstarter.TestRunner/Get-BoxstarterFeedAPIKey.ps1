function Get-BoxstarterFeedAPIKey {
<#
.SYNOPSIS
Gets the API key for the specified Nuget feed

.DESCRIPTION
Boxstarter can automatically publish a successfully tested Chocolatey 
package to its associated feed. In order for this to work, Boxstarter 
must have a valid API key authorized to publish to the feed. 
Get-BoxstarterFeedAPIKey retrieves an individual API key associated 
with a given nuget feed URL. Use Set-BoxstarterFeedAPIKey to specify 
a key to be associated with a feed.

.PARAMETER NugetFeed
The URI of a Nuget feed for which the API key is being queried.

.Example
Get-BoxstarterFeedAPIKey "http://chocolatey.org/api/v2"

Retrieves the API Key used with the public Chocolatey feed

.LINK
http://boxstarter.org
Set-BoxstarterFeedAPIKey
#>
    [CmdletBinding()]
    param (
        [URI]$NugetFeed
    )

    $path=Get-FeedsAPIKeyPath
    $fallbackPath = "$($Boxstarter.BaseDir)\BuildPackages\BoxstarterScripts\FeedAPIKeys.xml"

    if(Test-Path $path) {
        $keys = Import-CliXML $path
    }
    elseif(Test-Path $fallbackPath) {
        $keys = Import-CliXML $fallbackPath
    }
    else {
        $keys =  @{}
    }

    if($NugetFeed -and $keys.ContainsKey($NugetFeed)) {
        return $keys.$NugetFeed
    }
}