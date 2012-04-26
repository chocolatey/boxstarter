
$scriptPath = (Split-Path -parent $MyInvocation.MyCommand.path)
Import-Module $env:systemdrive\chocolatey\chocolateyinstall\helpers\chocolateyInstaller.psm1
if(${env:ProgramFiles(x86)} -ne $null){ $programFiles86 = ${env:ProgramFiles(x86)} } else { $programFiles86 = $env:ProgramFiles }
$drop = Join-Path $env:TEMP "testdriven"
$exe = "$drop\Setup.exe"
#Install-ChocolateyZipPackage 'TestDriven' 'http://www.testdriven.net/downloads/TestDriven.NET-3.3.2779_Personal_Beta2.zip' $drop
#Install-ChocolateyInstallPackage "TestDriven" 'exe' "/quiet" $exe
$newAddin = "$programFiles86\TestDriven.NET 3\TestDriven2011.AddIn"
#copy-item "$programFiles86\TestDriven.NET 3\TestDriven2010.AddIn" $newAddin
(Get-Content $newAddin) | % {$_ -replace "<Version>10.0</Version>", "<Version>11.0</Version>"} | Set-Content -path $newAddin
