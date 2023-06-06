# Boxstarter

![https://ci.appveyor.com/api/projects/status/github/chocolatey/boxstarter](https://ci.appveyor.com/api/projects/status/github/chocolatey/boxstarter?svg=true&branch=master)

Repeatable, reboot resilient windows environment installations made easy using Chocolatey packages

## For more information and How Tos, visit [the official Boxstarter website](https://boxstarter.org)

The source of the Boxstarter website can be found in the [boxstarter.org repository](https://github.com/chocolatey/boxstarter.org).

## Windows environment creation made easy

* 100% Unattended Install with *pending reboot detection* and *automatic logon*.
* Remote machine deployments
* Integrates with Hyper-V and Windows Azure VMs supporting checkpoint restore and creation
* Installation packages build on top of [Chocolatey](https://chocolatey.org) package management
* Easily install with just a [Gist and the Boxstarter Web Launcher](https://boxstarter.org/WebLauncher) or [create a private repository on a thumb drive or network share](https://boxstarter.org/InstallingPackages#InstallFromShare)
* Works on Window 7/2008 R2 and up with PowerShell 2.0 and higher
* Lots of Windows configuration utilities including installing critical updates, changing windows explorer options, and more.

## Quickly install your favorite applications and settings, on any machine, with a gist! No pre-installed software needed

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

## Information

* [Boxstarter Website](https://boxstarter.org)
* [Mailing List](https://groups.google.com/forum/#!forum/boxstarter)
* [Twitter](https://twitter.com/chocolateynuget) / [Facebook](https://www.facebook.com/ChocolateySoftware) / [GitHub](https://github.com/chocolatey)
* [Blog](https://chocolatey.org/blog) / [Newsletter](https://us8.list-manage.com/subscribe?u=86a6d80146a0da7f2223712e4&id=73b018498d)
* [Documentation](https://boxstarter.org/whyboxstarter)
* [Community Chat](https://ch0.co/community)

### Documentation

Please see the [Boxstarter docs](https://boxstarter.org/whyboxstarter).

### Requirements

Boxstarter requires the following to work:

* OS: Windows 7 or Windows Server 2008 R2 and higher
* PowerShell Version 2 or higher
* Administrative privileges on the machine where Boxstarter is running

### License / Credits

Apache 2.0 - see [LICENSE](https://github.com/chocolatey/boxstarter/blob/master/LICENSE.txt) and [NOTICE](https://github.com/chocolatey/boxstarter/blob/master/NOTICE.txt) files.

## Etiquette Regarding Communication

If you are an open source user requesting support, please remember that most folks in the Chocolatey community are volunteers that have lives outside of open source and are not paid to ensure things work for you, so please be considerate of others' time when you are asking for things. Many of us have families that also need time as well and only have so much time to give on a daily basis. A little consideration and patience can go a long way. After all, you are using a pretty good tool without cost. It may not be perfect (yet), and we know that.

## Submitting Issues

![submitting issues](https://cloud.githubusercontent.com/assets/63502/12534554/6ea7cc04-c224-11e5-82ad-3805d0b5c724.png)

* If you are having issues with a Chocolatey package, please see the [Chocolatey package triage process](https://chocolatey.org/docs/package-triage-process).
* If you are having issues with Chocolatey please see [Troubleshooting](https://github.com/chocolatey/choco/wiki/Troubleshooting) and the [FAQ](https://github.com/chocolatey/choco/wiki/ChocolateyFAQs) to see if your question or issue already has an answer.

Observe the following help for submitting an issue:

Prerequisites:

* The issue has to do with Boxstarter itself or the [Boxstarter website](https://boxstarter.org) and is not a Chocolatey package issue.
* Please check to see if your issue already exists with a quick search of the issues. Start with one relevant term and then add if you get too many results.
* You are not submitting an "Enhancement". Enhancements should observe [CONTRIBUTING](https://github.com/chocolatey/boxstarter/blob/master/CONTRIBUTING.md) guidelines.
* You are not submitting a question - questions are better served as [emails](https://groups.google.com/forum/#!forum/boxstarter) or [Community Chat](https://ch0.co/community).
* Please make sure you've read over and agree with the [etiquette regarding communication](#etiquette-regarding-communication).

Submitting a ticket:

* We'll need debug and verbose output, so please run and capture the log with `-Debug -Verbose` (ie. `Install-Boxstarter -PackageName <PACKAGE NAME OR GIST> -Verbose -Debug`. If it is less than 50 lines you can submit that with the issue or if it is longer, [create a gist](https://help.github.com/articles/creating-gists/) and link it.
* **Please note** that the debug/verbose output for some commands may have sensitive data (passwords or API Keys) related so please remove those if they are there prior to submitting the issue.
* If your issue needs output from `choco.exe`, then it logs to a file in `$env:ChocolateyInstall\log\`. You can grab the specific log output from there so you don't have to capture or redirect screen output. Please limit the amount included to just the command run (the log is appended to with every command).
* Please save the log output in a [gist](https://gist.github.com) (save the file as `log.sh`) and link to the gist from the issue. Feel free to create it as secret so it doesn't fill up against your public gists. Anyone with a direct link can still get to secret gists. If you accidentally include secret information in your gist, please delete it and create a new one (gist history can be seen by anyone) and update the link in the ticket (issue history is not retained except by email - deleting the gist ensures that no one can get to it). Using gists this way also keeps accidental secrets from being shared in the ticket in the first place as well.
* We'll need the entire log output from the run, so please don't limit it down to areas you feel are relevant. You may miss some important details we'll need to know. This will help expedite issue triage.
* It's helpful to include the version of Boxstarter, the version of the OS, whether running on physical or virtual hardware and the version of PowerShell - the debug script should capture all of those pieces of information.
* Include screenshots and / or animated gifs whenever possible as they help show us exactly what the problem is.

## Contributing

If you would like to contribute code or help squash a bug or two, that's awesome. Please familiarize yourself with [CONTRIBUTING](https://github.com/chocolatey/boxstarter/blob/master/CONTRIBUTING.md).

## Committers

Committers, you should be very familiar with [COMMITTERS](https://github.com/chocolatey/boxstarter/blob/master/COMMITTERS.md).
