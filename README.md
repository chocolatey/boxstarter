# Boxstarter

Repeatable, reboot resilient windows environment installations made easy using Chocolatey packages

## For more information and How Tos, visit [the official Boxstarter website](https://boxstarter.org)

## Windows environment creation made easy!

* 100% Unattended Install with *pending reboot detection* and *automatic logon*.
* Remote machine deployments
* Integrates with Hyper-V and Windows Azure VMs supporting checkpoint restore and creation
* Installation packages build on top of [Chocolatey](https://chocolatey.org) package management
* Easily install with just a [Gist and the Boxstarter Web Launcher](https://boxstarter.org/WebLauncher) or [create a private repository on a thumb drive or network share](https://boxstarter.org/InstallingPackages#InstallFromShare)
* Works on Window 7/2008 R2 and up with PowerShell 2.0 and higher
* Lots of Windows configuration utilities including installing critical updates, changing windows explorer options, and more.

## Quickly install your favorite applications and settings, on any machine, with a gist! No pre-installed software needed.

### Grab your Gist

![gist](Web/Images/gist3.PNG)

### Launch the Boxstarter launcher

![boxstarter weblauncher](Web/Images/start.png)

## Easily package installation scripts and resources in a NuGet package

### A simple Hello World

```powershell
Import-Module Boxstarter.Chocolatey
New-BoxstarterPackage HelloWorld
Set-Content (Join-Path $Boxstarter.LocalRepo "HelloWorld\Tools\ChocolateyInstall.ps1") `
  -Value "Write-Host `"Hello World! from `$env:COMPUTERNAME`";CINST Git" -Force
Invoke-BoxstarterBuild HelloWorld
```

### Install on another machine

```powershell
$creds=Get-Credential win7\mwrock
Install-BoxstarterPackage -ComputerName win7 `
  -Package HelloWorld -Credential $creds
```

![Remote Install](Web/Images/result.png)

**NOTE:** PowerShell Remoting must be enabled on the remote machine. Launch a PowerShell Console as administrator:

```powershell
Enable-PSRemoting -Force
```
