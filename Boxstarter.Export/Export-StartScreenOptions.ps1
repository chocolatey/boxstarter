function Export-StartScreenOptions {
<#
.SYNOPSIS
Exports the options for the Windows Start Screen.

.LINK
http://boxstarter.org

#>    

	$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
    $startPageKey = "$key\StartPage"
    $accentKey = "$key\Accent"

	Write-BoxstarterMessage "Exporting Windows Start Screen options..."

	$args = @()
	if(Test-Path -Path $startPageKey) {
        $args += switch ((Get-ItemProperty $startPageKey).OpenAtLogon) 
                 { 0 {"EnableBootToDesktop"} 
                   1 {"DisableBootToDesktop"} }
		$args += switch ((Get-ItemProperty $startPageKey).MonitorOverride) 
                 { 1 {"EnableShowStartOnActiveScreen"} 
                   0 {"DisableShowStartOnActiveScreen"} }
		$args += switch ((Get-ItemProperty $startPageKey).MakeAllAppsDefault) 
                 { 1 {"EnableShowAppsViewOnStartScreen"} 
                   0 {"DisableShowAppsViewOnStartScreen"} }
		$args += switch ((Get-ItemProperty $startPageKey).GlobalSearchInApps) 
                 { 1 {"EnableSearchEverywhereInAppsView"}
                   0 {"DisableSearchEverywhereInAppsView"} }
		$args += switch ((Get-ItemProperty $startPageKey).DesktopFirst) 
                 { 1 {"EnableListDesktopAppsFirst"} 
                   0 {"DisableListDesktopAppsFirst"} }
	}

	if(Test-Path -Path $accentKey) {
        $args += switch ((Get-ItemProperty $accentKey).MotionAccentId_v1.00) 
                 { 219 {"EnableDesktopBackgroundOnStart"}
                   221 {"DisableDesktopBackgroundOnStart"} }
    }

	[PSCustomObject]@{"Command" = "Set-StartScreenOptions"; "Arguments" = $args}
}