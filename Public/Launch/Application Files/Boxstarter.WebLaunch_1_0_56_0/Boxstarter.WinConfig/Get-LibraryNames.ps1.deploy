function Get-LibraryNames {
<#
.SYNOPSIS
Lists all Windows Library folders (My Pictures, personal, downloads, etc)

.DESCRIPTION
Libraries are special folders that map to a specific location on disk. These are usually found somewhere under $env:userprofile. This function can be used to discover the existing libraries and then use Move-LibraryDirectory to move the path of a library if desired.

.LINK
http://boxstarter.codeplex.com
Move-LibraryDirectory

#>
    $shells = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders'
    $retVal = @()
    (Get-Item $shells).Property | % {
        $property = ( Get-ItemProperty -Path $shells -Name $_ )
        $retVal += @{ "$_"=$property."$_" }
    }
    return $retVal
}
