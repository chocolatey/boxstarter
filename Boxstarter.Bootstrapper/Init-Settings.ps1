if (!$Global:Boxstarter) { 
    $Global:Boxstarter = @{ } 
}
if (!$Boxstarter.ContainsKey('Log')) {
    $Boxstarter.Log = "$(Get-BoxstarterTempDir)\boxstarter.log"
}
if (!$Boxstarter.ContainsKey('RebootOk')) { 
    $Boxstarter.RebootOk = $false 
}
if (!$Boxstarter.ContainsKey('IsRebooting')) { 
    $Boxstarter.IsRebooting = $false 
}
if (!$Boxstarter.ContainsKey('StopOnPackageFailure')) { 
    $Boxstarter.StopOnPackageFailure = $false 
}
