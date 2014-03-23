function Publish-BoxstarterPackage {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true, Position=0, ValueFromPipeline=$True)]
        [string[]]$PackageName
    )

    process {
        $PackageName | % {
            $err = $null
            $pkg = Get-BoxstarterPackages $_ 
            if($pkg -eq $null) {
                $err = "Could not find a pakage with ID $_ in the repository."
                Write-Error $err -Category InvalidArgument
            }
            elseif($pkg.Feed -eq $null) {
                $err = "Cannot publish $_ with no feed to publish to."
                Write-Error $err -Category InvalidOperation
            }
            elseif((Get-BoxstarterFeedAPIKey $pkg.Feed) -eq $null) {
                $err = "Cannot publish $_ to $feed with no API key."
                Write-Error $err -Category InvalidOperation
            }
            else {
                $err = @()
                $nupkg = join-path $Boxstarter.LocalRepo "$_.$($pkg.Version).nupkg"
                Write-BoxstarterMessage "Calling nuget: push $nupkg $(Get-BoxstarterFeedAPIKey $pkg.Feed) -Source $($pkg.Feed)/package -NonInteractive" -Verbose
                $err += Invoke-NugetPush $pkg $nupkg 2>&1
                try {
                    $publishedVersion = Get-BoxstarterPackagePublishedVersion $pkg.id $pkg.Feed -ErrorAction Stop
                }
                catch{
                    $err += $_
                }
                if($publishedVersion -eq $null -or $publishedVersion -eq $pkg.Version) {
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
