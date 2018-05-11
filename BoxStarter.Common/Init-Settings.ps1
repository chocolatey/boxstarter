if(!$Global:Boxstarter) {
    $Global:Boxstarter = @{}
    $Boxstarter.SuppressLogging=$false
}
$Boxstarter.BaseDir=(Split-Path -parent ((Get-Item $PSScriptRoot).FullName))

