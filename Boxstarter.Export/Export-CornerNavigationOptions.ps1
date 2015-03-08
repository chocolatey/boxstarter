function Export-CornerNavigationOptions {
<#
.SYNOPSIS
Exports options for the Windows Corner Navigation

.LINK
http://boxstarter.org

#>
    $edgeUIKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ImmersiveShell\EdgeUi'
    $advancedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

    Write-BoxstarterMessage "Exporting Corner Navigation options..."
    
    $args = @()
    if(Test-Path -Path $edgeUIKey) {
        $args += switch ((Get-ItemProperty $edgeUIKey).DisableTRCorner) { 
                     0 {"EnableUpperRightCornerShowCharms"} 
                     1 {"DisableUpperRightCornerShowCharms"}
                 }
        $args += switch ((Get-ItemProperty $edgeUIKey).DisableTLCorner) {
                     0 {"EnableUpperLeftCornerSwitchApps"} 
                     1 {"DisableUpperLeftCornerSwitchApps"} 
                 }
    }

    if(Test-Path -Path $advancedKey) {
        $args += switch ((Get-ItemProperty $advancedKey).DontUsePowerShellOnWinX) { 
                     0 {"EnableUsePowerShellOnWinX"} 
                     1 {"DisableUsePowerShellOnWinX"} 
                 }
    }

    [PSCustomObject]@{"Command" = "Set-CornerNavigationOptions"; "Arguments" = $args}
}