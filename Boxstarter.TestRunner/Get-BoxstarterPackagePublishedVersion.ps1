function Get-BoxstarterPackagePublishedVersion {
    [CmdletBinding()]
    param(
        [string]$PackageId,
        [URI]$Feed
    )

    try {
        if(!$feed) {
            return $null
        }
        else {
            $feedUrl="$feed/Packages/?`$filter=Id eq '$PackageId' and IsLatestVersion&`$select=Version"
            $downloader=new-object net.webclient
            $wp=[system.net.WebProxy]::GetDefaultProxy()
            $wp.UseDefaultCredentials=$true
            $downloader.Proxy=$wp
            [xml]$response = $downloader.DownloadString($feedUrl )
            $publishedPkg=$response.feed.entry
            return $publishedPkg.Properties.Version
        }
    }
    catch {
        Write-BoxstarterMessage "Error occurred querying $feed for published version of $packageId : $($_.Message)" -Verbose
    }
}