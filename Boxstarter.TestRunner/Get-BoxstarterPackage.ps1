function Get-BoxstarterPackage {
<#
.SYNOPSIS
Retrieves metadata for all packages in the Local Boxstarter repository
or an individual package.

.DESCRIPTION
Get-BoxstarterPackage retrieves information about either a single package
or all packages in the Local Boxstarter repository if no PackageName
parameter is provided. This information includes package ID, version, the
latest version published to the packages NuGet feed and the feed URI.

.PARAMETER PackageName
The name of a Chocolatey package in the local repository for which to
retrieve metadata. If this parameter is not provided then information for
all packages is provided.

.Example
Get-BoxstarterPackage MyPackageName

Retrieves package metadata for MyPackageName

.Example
Get-BoxstarterPackage

Retrieves package metadata for all packages in the Boxstarter Local repository


.LINK
https://boxstarter.org
#>
    [CmdletBinding()]
    param(
        [string[]]$PackageName
    )

    pushd $Boxstarter.LocalRepo
    try {
        Get-ChildItem . | ? { Test-Path (Join-Path $_.name "$($_.name).nuspec") } | ? {
            !$PackageName  -or $packagename -contains $_.name
        } | % {
            $nuspecPath=Join-Path $_.name "$($_.name).nuspec"
            [xml]$nuspec = Get-Content $nuspecPath
            $feed = Get-BoxstarterPackageNugetFeed -PackageName $_
            $publishedVersion = Get-BoxstarterPackagePublishedVersion $nuspec.package.metadata.id $feed
            New-Object PSObject -Property @{
                Id = $nuspec.package.metadata.id
                Version = $nuspec.package.metadata.version
                PublishedVersion=$publishedVersion
                Feed=$feed
            }
        }
    }
    finally {
        popd
    }
}
