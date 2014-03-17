function Publish-BoxstarterPackage {
    [CmdletBinding()]
    param(
        [string[]]$PackageName
    )

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
            $err += Invoke-NugetPush $pkg 2>&1
            try {
                $publishedVersion = Get-BoxstarterPackagePublishedVersion $nuspec.package.metadata.id $feedUrl -ErrorAction Stop
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

function Invoke-NugetPush ($pkg) {
    $nuget="$env:ChocolateyInstall\chocolateyinstall\Nuget.exe"
    .$nuget push (join-path $Boxstarter.LocalRepo "$_.$($pkg.RepoVersion).nupkg") (Get-BoxstarterFeedAPIKey $pkg.Feed) -Source $pkg.Feed -NonInteractive
}
