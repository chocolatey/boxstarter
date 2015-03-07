function Export-WindowsExplorerOptions {
<#
.SYNOPSIS
Exorts the current Windows Explorer shell options

.LINK
http://boxstarter.org

#>
	$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
    $advancedKey = "$key\Advanced"
	$cabinetStateKey = "$key\CabinetState"

	Write-BoxstarterMessage "Exporting current Windows Explorer shell options..."

	$args = @()
	if(Test-Path -Path $advancedKey) {
        $args += switch ((Get-ItemProperty $advancedKey).Hidden) 
                 { 1 {"EnableShowHiddenFilesFoldersDrives"} 
                   0 {"DisableShowHiddenFilesFoldersDrives"} }
        $args += switch ((Get-ItemProperty $advancedKey).HideFileExt) 
                 { 0 {"EnableShowFileExtensions"} 
                   1 {"DisableShowFileExtensions"} }
        $args += switch ((Get-ItemProperty $advancedKey).ShowSuperHidden)
                 { 1 {"EnableShowProtectedOSFiles"} 
                   0 {"DisbleShowProtectedOSFiles"} }
	}

    if(Test-Path -Path $cabinetStateKey) {
        $args += switch ((Get-ItemProperty $cabinetStateKey).FullPath) 
                 { 1 {"EnableShowFullPathInTitleBar"} 
                   0 {"DisableShowFullPathInTitleBar"} }
    }
    
    [PSCustomObject]@{"Command" = "Set-WindowsExplorerOptions"; "Arguments" = $args}
}