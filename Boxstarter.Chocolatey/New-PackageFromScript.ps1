function New-PackageFromScript {
    [CmdletBinding()]
	param (
        [Parameter(Mandatory=1)]
        [string] $Source
    )

    Check-Chocolatey
    . "$env:ChocolateyInstall\chocolateyinstall\helpers\functions\Get-WebFile.ps1"
    if($source -like "*://*"){
        try {$text = Get-WebFile -url $Source -passthru } catch{
            throw "Unable to retrieve script from $source `r`nInner Exception is:`r`n$_"
        }
    }
    else {
        if(!(Test-Path $source)){
            throw "Path $source does not exist."
        }
        $text=Get-Content $source
    }

    $thisPackageName="temp_$env:Computername"
    if(Test-Path "$($boxstarter.LocalRepo)\$thisPackageName"){
        Remove-Item "$($boxstarter.LocalRepo)\$thisPackageName" -recurse -force
    }
    New-BoxstarterPackage $thisPackageName -quiet
    Set-Content "$($boxstarter.LocalRepo)\$thisPackageName\tools\ChocolateyInstall.ps1" -value $text
    Invoke-BoxstarterBuild $thisPackageName -quiet

    Write-BoxstarterMessage "Created a temporary package $thisPackageName from $source in $($boxstarter.LocalRepo)"
    return $thisPackageName
}