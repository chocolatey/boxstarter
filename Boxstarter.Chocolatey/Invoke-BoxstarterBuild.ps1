function Invoke-BoxStarterBuild {
<#
.SYNOPSIS
Packs a specific package or all packages in the Boxstarter Repository

.DESCRIPTION
Invoke-BoxStarterBuild packs either a single package or all packages
in the local repository. The packed .nupkg is placed in the root of
the Repo and is then able to be consumed by 
Invoke-ChocolateyBoxstarter.

.PARAMETER Name
The name of the package to pack

.PARAMETER All
Indicates that all package directories in the repository should be packed

.LINK
http://boxstarter.codeplex.com
about_boxstarter_chocolatey
Invoke-BoxstarterBuild
New-BoxstarterPackage
#>    
    param(
        [Parameter(Position=0,ParameterSetName='name')]
        [string]$name,
        [Parameter(Position=0,ParameterSetName='all')]
        [switch]$all
    )
    Check-Chocolatey
    $choco="$env:ChocolateyInstall\chocolateyinstall\chocolatey.ps1"
    if(!$boxstarter -or !$boxstarter.LocalRepo){
        throw "No Local Repository has been set in `$Boxstarter.LocalRepo."
    }
    pushd $Boxstarter.LocalRepo
    try{
        if($name){
            if(!(Test-Path (join-path $name "$name.nuspec"))){
                throw "Cannot find nuspec for $name"
            }
            .$choco Pack (join-path $name "$name.nuspec")
        } else {
             if($all){
                Get-ChildItem . | ? { $_.PSIsContainer } | % {
                    if(!(Test-Path (join-path $_.name "$($_.name).nuspec"))){
                        throw "Cannot find nuspec for $_"
                    }
                    .$choco Pack (join-path . "$($_.Name)\$($_.Name).nuspec")
                }                
            }
        }
    }
    finally {
        popd    
    }
}