function Get-HttpResource {
<#
.SYNOPSIS
Downloads the contents from a URL

.DESCRIPTION
Get-HttpResource downloads the contents of an HTTP url.
When -PassThru is specified it returns the string content.

.PARAMETER Url
The url containing the content to download.

.PARAMETER OutputPath
If provided, the content will be saved to this path.

.PARAMETER PassThru
If provided, the string will be output to the pipeline.

.EXAMPLE
$content = Get-HttpResource -Url 'http://my/url' `
                            -OutputPath 'c:\myfile.txt' `
                            -PassThru

This downloads the content located at http://my/url and
saves it to a file at c:\myfile.txt and also returns
the downloaded string.

.LINK
https://boxstarter.org

#>
    param (
        [string]$Url,
        [string]$OutputPath = $null,
        [switch]$PassThru
    )
    Write-BoxstarterMessage "Downloading $url" -Verbose
    $str = Invoke-RetriableScript -RetryScript {
        $downloader=new-object net.webclient
        $wp=[system.net.WebProxy]::GetDefaultProxy()
        $wp.UseDefaultCredentials=$true
        $downloader.Proxy=$wp
        $downloader.UseDefaultCredentials=$true
        try {
            if($args[1]) {
                Write-BoxstarterMessage "Saving $($args[0]) to $($args[1])" -Verbose
                $downloader.DownloadFile($args[0], $args[1])
            }
            else {
                $downloader.DownloadString($args[0])
            }
        }
        catch{
            if($VerbosePreference -eq "Continue"){
                Write-Error $($_.Exception | fl * -Force | Out-String)
            }
            throw $_
        }
    } $Url $OutputPath

    if($PassThru) {
        if($str) {
            Write-Output $str
        }
        elseif($OutputPath) {
            Get-Content -Path $OutputPath
        }
    }
}
