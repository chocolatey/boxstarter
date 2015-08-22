@{
Description = 'Provides Cmdlets that will install a boxstarter package on a Windows Azure VM'
# Script module or binary module file associated with this manifest.
ModuleToProcess = './boxstarter.Azure.psm1'

# Version number of this module.
ModuleVersion = '2.5.21'

# ID used to uniquely identify this module
GUID = 'bbdb3e8b-9daf-4c00-a553-4f3f88fb6e59'

# Author of this module
Author = 'Matt Wrock'

# Copyright statement for this module
Copyright = '(c) 2015 Matt Wrock'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '3.0'

# Minimum version of the .NET Framework required by this module
DotNetFrameworkVersion = '4.0'

RequiredAssemblies = @( "$env:ProgramW6432\Microsoft SDKs\Azure\.NET SDK\v2.5\bin\plugins\Caching\Microsoft.WindowsAzure.StorageClient.dll" )

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
NestedModules = @('..\Boxstarter.Common\Boxstarter.Common.psd1','..\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1')

# Functions to export from this module
FunctionsToExport = '*'

# Cmdlets to export from this module
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module
AliasesToExport = '*'

# List of all modules packaged with this module.
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess
PrivateData = 'd34e4476c2e7409f392a5f42af2aa4191f194577'

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

