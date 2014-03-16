function Publish-BoxstarterPackage {
    [CmdletBinding()]
    param(
        [string[]]$PackageName
    )

    $PackageName | % {
        [PSCustomObject]@{
            Package=$null
            Feed=$null
            PublishedVersion=$null
            PulishErrors=$null
        }
    }
}
