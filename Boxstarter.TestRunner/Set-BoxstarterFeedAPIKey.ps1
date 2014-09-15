function Set-BoxstarterFeedAPIKey {
<#
.SYNOPSIS
Sets the API key for the specified Nuget feed

.DESCRIPTION
Boxstarter can automatically publish a succesfully tested Chocolatey 
package to its asociated feed. In order for this to work, Boxstarter 
must have a valid API key authorized to publish to the feed. 
Set-BoxstarterFeedAPIKey associates an individual API key with a 
given nuget feed url. Use Get-BoxstarterFeedAPIKey to retrieve 
a key associated with a feed.

.PARAMETER NugetFeed
The URI of a Nuget feed for which the API key is being associated.

.PARAMETER APIKey
The GUID API Key to assiciate with the feed.

.NOTES
These keys are persisted to a file in encrypted format.

.Example
Set-BoxstarterFeedAPIKey -NugetFeed "http://chocolatey.org/api/v2" `
  -APIKey 5cbc38d9-1a94-430d-8361-685a9080a6b8

Sets the API Key used with the public Chocolatey feed to 
5cbc38d9-1a94-430d-8361-685a9080a6b8.

.LINK
http://boxstarter.org
Get-BoxstarterFeedAPIKey
#>
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