# Notes for Boxstarter v3

## Goals

### A more precise separation between boxstarter and provisioner(chocolatey)
Boxstarter began with the intention of abstracting reboot resiliancy and being capable of running ANY script (chocolatey or not) in an unattended rebootable manner. Shortcuts have been taken it spots that hard wire Boxstarter and chocolatey especially with remote execution. All remote execution code is in the chocolatey module.

### Work with other Provisioners
Currently chocolatey is the only provisioner. We also want to work with chef, puppet, DSC, etc.

### Ability to compose multiple provisioners in a single install.
This is up for debate. The thought being maybe you have a bunch of install automation that leverages chocolatey but there is a chef cookbook, DSC resource or puppet module that does something you want to include. I question the value here since many of these provisioners already allow you to nest one another. For example, you can use the Chocolatey or Boxtarter cookbook in chef and use chef to consume DSC  resources. It still makes sense to explore this.

### Clean up the execution workflow of a boxstarter run. Its current recursive pattern makes it overly complicated

**Current workflow**
```
Install-BoxstarterPackage(entry point) -> 
Invoke-ChocolateyBoxstarter -> 
Invoke-Boxstarter -> 
Invoke-ChocolateyBoxstarter
```

If not running as admin, `Invoke-Boxstarter` will open a new elevated shell and call itself.

### Cross-platform
I **think** there is value in providing rebootable linux installs (this does happen), but more importantly I may want to perform a remote windows instal from linux/mac.

### More secure and less intrusive
* No more futzing with UAC. One possibility is do everything via scheduled tasks.
* No More Auto logon because LSA secrets are not that secret. Boxstarter uses a windows API to store the autologon password in an encrypted format but it is far too easy to ecrypt this. One alternative tequnique to use for experimentation is creating a scheduled task that runs `ONSTART`. The question here is when/if the user does login, will they "see" the install and know when it is done? I'm sure this can be solved.

## So what is "Boxstarter Core"
* Wraps an installation script so that reboots can happen and the install continues.
* Provides an easy to remember HTTP endpoint that installs itself with no preinstalled software necessary.
* Can run installs remotely in an "agentless" manner
* Install packages/scripts can sit anywhere that can be reached via http. You may but do not need to create and publish packages to a public repo. In other words, no need to wory about getting a package on chocolatey.org or a cookbook on a chef server. Provisioner plugins should be able to hide these details. Just put your chocolateyInstall.ps1 or recipe.rb content in a gist or dropbox and boxstarter figures it out.

## Write in GO?
I'm considering rewriting the core of boxstarter in GO for these reasons.
* Its cross platform
* Its statically typed. I do love dynamically typed languages but personally prefer static for larger projects or projects that have real users.
* Is not c++
* I want to learn it. Yeah I said it.

Once some design decisions have been ironed out, it may make more sense to remain in pure powershell and then port to GO later after the basic structure is stable or maybe not. Regardless, there will be a powershell module to wrap the core so users can still call boxstarter via powershell commands.

## Thoughts on revised execution flow

```
Invoke-Boxstarter(includes install boxstarter package) -> 
Invoke-ChocolateyBoxstarter(or other  provisioner(s))
```

* Boxstarter core is the entrypoint and arguments guide the provisioner(s)
* Possibly the script that boxstarter runs and not the arguments instruct which provisioner to load and run.
* Much simpler

### Problems
* If provisionr to use is based on CLI args, `Invoke-Boxstarter` arguments need to work accross provisioners which could be limiting.

```
Invoke-ChocolateyBoxstarter -> 
Invoke-Boxstarter
```

* The provisioner is the entry point that adheres to an interface defined by boxstarter core and calls its API 
* Allows for a calling syntax that cators to the specifics of the provisioner

## Problems
* Only makes sense if using a single provisioner