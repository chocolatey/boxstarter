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
        $args += if ((Get-ItemProperty $advancedKey).Hidden -eq 1) { "EnableShowHiddenFilesFoldersDrives" } else { "DisableShowHiddenFilesFoldersDrives" }
        $args += if ((Get-ItemProperty $advancedKey).HideFileExt -eq 0) { "EnableShowFileExtensions" } else { "DisableShowFileExtensions" }
        $args += if ((Get-ItemProperty $advancedKey).ShowSuperHidden -eq 1) { "EnableShowProtectedOSFiles" } else { "DisbleShowProtectedOSFiles" }
	}

    if(Test-Path -Path $cabinetStateKey) {
        $args += if ((Get-ItemProperty $cabinetStateKey).FullPath -eq 1) { "EnableShowFullPathInTitleBar" } else { "DisableShowFullPathInTitleBar" }
    }
    
    [PSCustomObject]@{"Command" = "Set-WindowsExplorerOptions"; "Arguments" = $args}
}