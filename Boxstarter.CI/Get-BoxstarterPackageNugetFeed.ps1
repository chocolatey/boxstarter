function Get-BoxstarterPackageNugetFeed {
    [CmdletBinding()]
    param (
        [string]$packageName
    )

    $path=Get-PackageFeedsPath
    if(!(Test-Path $path)) { 
        $feeds =  @{}
    }
    else {
        $feeds = Import-CliXML $path
    }

    if($feeds.$packageName) {
        return $feeds.$packageName
    }
    else {
        return (Get-BoxstarterDeployOptions).DefaultNugetFeed
    }
}