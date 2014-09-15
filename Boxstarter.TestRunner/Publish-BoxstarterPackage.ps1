function Publish-BoxstarterPackage {
<#
.SYNOPSIS
Publishes a package to a Nuget feed

.DESCRIPTION
Publishes a package in the Boxstarter local repository to the Nuget feed 
it is associated with and using the API key that the feed has been 
assigned to. Set-BoxstarterPackageNugetFeed and Set-BoxstarterFeedAPIKey 
can be used to set the feed assigned to a package and the API key assigned 
to a feed. If no feed is explicitly assigned to a package, then the 
Default Nuget Feed of the BoxstarterDeployOptions is used. This can be set 
using Set-BoxstarterDeployOptions and if no default feed is set, the public 
chocolatey feed is used. A package feed can be cleared by using 
Remove-BoxstarterPackageNugetFeed. It will then use the default nuget feed. 
If you want to ensure that a package is never associated with a feed 
including the default feed, use Set-BoxstarterPackageNugetFeed and set
the feed to $null.

.PARAMETER PackageName

The name of the package in the Boxstarter LocalRepo to publish.

.Example
Set-BoxstarterPackageNugetFeed -PackageName MyPackage -NugetFeed https://www.myget.org/F/MyFeed/api/v2
Set-BoxstarterFeedAPIKey -NugetFeed https://www.myget.org/F/MyFeed/api/v2 -APIKey 2d2cfb67-8203-45d8-8a00-4e737f517c79
Publish-BoxstarterPackage MyPackage

Assigns the MyGet MyFeed to MyPackage and sets 
2d2cfb67-8203-45d8-8a00-4e737f517c79 as its API Key. When 
Publish-BoxstarterPackage is called for MyPackage, it is published to the 
MyFeed feed on MyGet.org using 2d2cfb67-8203-45d8-8a00-4e737f517c79.

.LINK
http://boxstarter.org
Get-BoxstarterPackageNugetFeed
Set-BoxstarterPackageNugetFeed
Remove-BoxstarterPackageNugetFeed
Get-BoxstarterFeedAPIKey
Set-BoxstarterFeedAPIKey
#>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true, Position=0, ValueFromPipeline=$True)]
        [string[]]$PackageName
    )

    process {
        $PackageName | % {
            $err = $null
            $pkg = Get-BoxstarterPackage $_ 
            if($pkg -eq $null) {
                $err = "Could not find a package with ID $_ in the repository."
                Write-Error $err -Category InvalidArgument
            }
            elseif($pkg.Feed -eq $null) {
                $err = "Cannot publish $_ with no feed to publish to."
                Write-Error $err -Category InvalidOperation
            }
            elseif((Get-BoxstarterFeedAPIKey $pkg.Feed) -eq $null) {
                $err = "Cannot publish $_ to $($pkg.feed) with no API key."
                Write-Error $err -Category InvalidOperation
            }
            else {
                $err = @()
                $nupkg = join-path $Boxstarter.LocalRepo "$_.$($pkg.Version).nupkg"
                Write-BoxstarterMessage "Calling nuget: push $nupkg $(Get-BoxstarterFeedAPIKey $pkg.Feed) -Source $($pkg.Feed)/package -NonInteractive" -Verbose
                $err += Invoke-NugetPush $pkg $nupkg 2>&1
                try {
                    for($count = 1; $count -le 5; $count++) {
                        $publishedVersion = Get-BoxstarterPackagePublishedVersion $pkg.id $pkg.Feed -ErrorAction Stop
                        if($publishedVersion.length -gt 0 -and ($publishedVersion -eq $pkg.Version) ) { break }
                        Write-BoxstarterMessage "no published version found, Trying again." -Verbose
                        if(!$script:testing){Start-Sleep -seconds 10}
                    }
                }
                catch{
                    $err += $_
                }
                if($publishedVersion -eq $null -or $publishedVersion -ne $pkg.Version) {
                    write-Error ($err -join ", " )
                }
                else {
                    $err = $null
                }
            }
            [PSCustomObject]@{
                Package=$(if($pkg.Id){$pkg.Id}else{$_})
                Feed=$pkg.Feed
                PublishedVersion=$publishedVersion
                PublishErrors=$err
            }
        }
    }
}

function Invoke-NugetPush ($pkg,$nupkg) {
    $nuget="$env:ChocolateyInstall\chocolateyinstall\Nuget.exe"
    .$nuget push $nupkg (Get-BoxstarterFeedAPIKey $pkg.Feed) -Source "$($pkg.Feed)/package" -NonInteractive
}
