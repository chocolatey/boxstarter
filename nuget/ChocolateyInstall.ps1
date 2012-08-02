try {
  $sysDrive = $env:SystemDrive
  $autoboxPath = "$sysDrive\tools\autobox"
  if ([System.IO.Directory]::Exists($autoboxPath)) {[System.IO.Directory]::Delete($autoboxPath,$true)}
  [System.IO.Directory]::CreateDirectory($autoboxPath)
  
  $autoboxFiles = Join-Path $(Split-Path -parent $MyInvocation.MyCommand.Definition) 'autobox'
  
  write-host "Copying the contents of `'$autoboxFiles`' to `'$autoboxPath`'" 
  Copy-Item "$($autoboxFiles)\*" $autoboxPath -recurse -force

  Write-ChocolateySuccess 'autobox'
} catch {
  Write-ChocolateyFailure 'autobox' $($_.Exception.Message)
  throw 
}