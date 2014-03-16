function Publish-BoxstarterPackage {
    [CmdletBinding()]
    param(
        [string[]]$PackageName
    )

    $PackageName | % {
        write-Host $_ 
    }
}
