if(!$Global:Boxstarter) { $Global:Boxstarter = @{} }
$Boxstarter.BaseDir=(Split-Path -parent ((Get-Item $PSScriptRoot).FullName))