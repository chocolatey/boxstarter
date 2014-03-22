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
            $feedUrl="$feed/Packages/?`$filter=Id eq '$($nuspec.package.metadata.id)' and IsLatestVersion&`$select=Version"
            $publishedPkg=Invoke-RestMethod -Uri $feedUrl -ErrorAction Stop
            return $publishedPkg.Properties.Version
        }
    }
    catch {
        Write-BoxstarterMessage "Error occured querying $feed for published version of $packageId : $($_.Message)" -Verbose
    }
}