function Get-BoxstarterPackages {
    pushd $Boxstarter.LocalRepo
    try {
        Get-ChildItem . | ? { Test-Path (join-path $_.name "$($_.name).nuspec") } | % {
            $nuspecPath=join-path $_.name "$($_.name).nuspec"
            [xml]$nuspec = Get-Content $nuspecPath 
            try {
                $feedUrl="http://chocolatey.org/api/v2/Packages/?`$filter=Id eq '$($nuspec.package.metadata.id)' and IsLatestVersion&`$select=Version"
                $publishedPkg=Invoke-RestMethod -Uri $feedUrl 
                $publishedVersion=$publishedPkg.Properties.Version
            }
            catch {
                Write-Host "err: $($_.ToString())"
            }
            New-Object PSObject -Property @{
                Id = $nuspec.package.metadata.id
                Version = $nuspec.package.metadata.version
                PublishedVersion=$publishedVersion
            }
        }
    }
    finally {
        popd
    }    
}