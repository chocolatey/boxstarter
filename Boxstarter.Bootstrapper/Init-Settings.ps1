if(!$Global:Boxstarter) { $Global:Boxstarter = @{} }
$Boxstarter.Log="$env:temp\boxstarter.log"
$Boxstarter.RebootOk=$false
$Boxstarter.SuppressLogging=$false
$Boxstarter.IsRebooting=$false
$Boxstarter.BaseDir=(Split-Path -parent ((Get-Item $PSScriptRoot).FullName))