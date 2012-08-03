try {
  $sysDrive = $env:SystemDrive
  $BoxStarterPath = "$sysDrive\tools\BoxStarter"
  if ([System.IO.Directory]::Exists($BoxStarterPath)) {[System.IO.Directory]::Delete($BoxStarterPath,$true)}
  [System.IO.Directory]::CreateDirectory($BoxStarterPath)
  
  $BoxStarterFiles = Join-Path $(Split-Path -parent $MyInvocation.MyCommand.Definition) 'BoxStarter'
  
  write-host "Copying the contents of `'$BoxStarterFiles`' to `'$BoxStarterPath`'" 
  Copy-Item "$($BoxStarterFiles)\*" $BoxStarterPath -recurse -force

  Write-ChocolateySuccess 'BoxStarter'
} catch {
  Write-ChocolateyFailure 'BoxStarter' $($_.Exception.Message)
  throw 
}