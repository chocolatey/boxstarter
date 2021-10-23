# Deploying Boxstarter

## Visual Studio Requirements

* At least Visual Studio 2013;
* PowerShell Tools for Visual Studio which you can install from [Chocolatey](https://chocolatey.org):
    * [Visual Studio 2013](https://www.chocolatey.org/packages/poshtools-visualstudio2013): `choco install poshtools-visualstudio2013 -y`
    * [Visual Studio 2015](https://chocolatey.org/packages/visualstudio2015-powershelltools): `choco install visualstudio2015-powershelltools -y`
    * [Visual Studio 2017](https://chocolatey.org/packages/visualstudio2017-powershelltools): `choco install visualstudio2017-powershelltools -y`

## Prerequisites

* Run `.\build.bat Install-ChocoPkg` - this will place the 'included' version of the Chocolatey nupkg into the Boxstarter.Chocolatey folder
* You will need a code signing certificate installed in your personal certificate store
* The thumbprint of that certificate needs to be specified in the `ManifestCertificateThumbprint` property inside the `Boxstarter.ClickOnce` `.csproj` file.
* You should set `$env:BOXSTARTER_GITHUB_USERNAME` to your GitHub username
* You should set `$env:BOXSTARTER_GITHUB_TOKEN` to your GitHub personal access token which should have rights to add releases to the Boxstarter GitHub repository.
* You should set `$env:BOXSTARTER_PUBLISH_PASSWORD` to the `boxstarter$` user's password which can be obtained from the Boxstarter Azure Website publisher profile. This assumes you have access to that profile.
* You should have a Chocolatey community feed api key configured and authorized to push new Boxstarter packages.

## Build the Deployable artifacts

**Note:**
If you are deploying a new Minor or Major version, make sure to `git tag` the repository with the new version before building. Do not include the build version - ex: `git tag 3.4`.

Now Build the artifacts from the root of the repository:

```
./build quick-deploy
```

If this is the first time you are running this command, it may take extra time to run as it ensures all prerequisites are installed (VS build tools, Azure PowerShell module, etc.).

This will compile the Boxstarter website and ClickOnce application and also sign the ClickOnce app. It will bump the version where the build version will be the number of commits since the minor version was tagged. It will update the Boxstarter homepage HTML to reflect this version and create new Chocolatey packages for all Boxstarter packages.

## Deploy the build

```
./build push-public
```

This wraps three tasks:

### Push-Chocolatey

Iterates all Chocolatey packages created in the above build and pushes them to the community Chocolatey community feed.

### Push-Github

Creates a new Github release in the Boxstarter repository.

### Publish-Web

Publishes all web artifacts to the Boxstarter website
