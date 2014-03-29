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
            $publishedPkg=Invoke-RestMethod -Uri $feedUrl -ErrorAction Stop
            return $publishedPkg.Properties.Version
        }
    }
    catch {
        Write-BoxstarterMessage "Error occurred querying $feed for published version of $packageId : $($_.Message)" -Verbose
    }
}