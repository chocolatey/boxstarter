function New-BoxstarterPackage {
<#
.SYNOPSIS
Creates a new Chocolatey package source directory intended for a Boxstarter Install

.DESCRIPTION
New-BoxstarterPackage creates a new Directory in your local
Boxstarter repository located at $Boxstarter.LocalRepo. If no path is
provided, Boxstarter creates a minimal nuspec and
ChocolateyInstall.ps1 file. If a path is provided, Boxstarter will
copy the contents of the path to the new package directory. If the
path does not include a nuspec or ChocolateyInstall.ps1, Boxstarter
will create one. You can use Invoke-BoxstarterBuild to pack the
repository directory to a Chocolatey nupkg. If your path includes
subdirectories, you can use Get-PackageRoot inside
ChocolateyInstall.ps1 to reference the parent directory of the copied
content.

.PARAMETER Name
The name of the package to create

.PARAMETER Description
Description of the package to be written to the nuspec

.PARAMETER Path
Optional path whose contents will be copied to the repository

.LINK
https://boxstarter.org
New-PackageFromScript
about_boxstarter_chocolatey
about_boxstarter_variable_in_chocolatey
Invoke-BoxstarterBuild
Get-PackageRoot
#>
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$description,
        [string]$path,
        [switch]$quiet
    )
    if(!$boxstarter -or !$boxstarter.LocalRepo){
        throw "No Local Repository has been set in `$Boxstarter.LocalRepo."
    }
    if(!($name -match "^\w+(?:[_.-]\w+)*$") -or ($name.length -gt 100)){
        throw "Invalid Package ID"
    }
    $pkgDir = Join-Path $Boxstarter.LocalRepo $Name
    if(test-path $pkgDir) {
        throw "A LocalRepo already exists at $($boxstarter.LocalRepo)\$name. Delete the directory before calling New-BoxstarterPackage"
    }
    MkDir $pkgDir | Out-Null
    Pushd $pkgDir
    if($path){
        if(!(test-path $Path)){
            popd
            throw "$path could not be found"
        }
        if(test-path "$Path\$Name.nuspec") {
            Copy-Item "$path\*" . -recurse
        }
        else { Copy-Item $path . -recurse }
    }
    $pkgFile = Join-Path $pkgDir "$name.nuspec"
    if(!(test-path $pkgFile)){
        $nuspec = @"
<?xml version="1.0"?>
<package >
  <metadata>
    <id></id>
    <version>1.0.0</version>
    <authors></authors>
    <owners></owners>
    <description>Package description</description>
    <tags>Tag1 Tag2</tags>
  </metadata>
</package>
"@

        Invoke-RetriableScript {
            [xml]$xml = $args[1]
            $metadata = $xml.package.metadata
            # Why ToString()? I have no idea but psv2 breaks without it
            # What I do know is I can't wait for psv2 to die
            $metadata.id = $args[2].ToString()
            if($args[3]){$metadata.Description=$args[3]}
            $metadata.authors = $env:USERNAME
            $metadata.owners = $env:USERNAME
            $metadata.tags="Boxstarter"
            $xml.Save($args[0])
        } $pkgFile $nuspec $Name $description
    }
    if(!(test-path "tools")){
        Mkdir "tools" | Out-Null
    }
    $installScript=@"
try {

    Write-ChocolateySuccess '$name'
} catch {
  Write-ChocolateyFailure '$name' `$(`$_.Exception.Message)
  throw
}
"@
    if(!(test-path "tools\ChocolateyInstall.ps1")){
        new-Item "tools\ChocolateyInstall.ps1" -type file -value $installScript| Out-Null
    }
    Popd

    if(!$quiet){
        Write-BoxstarterMessage "A new Chocolatey package has been created at $pkgDir." -nologo
        Write-BoxstarterMessage "You may now edit the files in this package and build the final .nupkg using Invoke-BoxstarterBuild." -nologo
    }
}
