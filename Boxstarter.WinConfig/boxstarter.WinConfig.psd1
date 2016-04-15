@{
Description = 'Provides Functions for customizing and configuring core windows settings'
# Script module or binary module file associated with this manifest.
ModuleToProcess = './boxstarter.WinConfig.psm1'

# Version number of this module.
ModuleVersion = '2.8.0'

# ID used to uniquely identify this module
GUID = 'bbdb3e8b-9daf-4c00-a553-4f3f88fb6e52'

# Author of this module
Author = 'Matt Wrock'

# Copyright statement for this module
Copyright = '(c) 2016 Matt Wrock.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '2.0'

# Minimum version of the .NET Framework required by this module
DotNetFrameworkVersion = '2.0'

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
NestedModules = @('..\Boxstarter.Common\Boxstarter.Common.psd1')

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
PrivateData = '9456b400eb106ee772a67a846971ebb6b49bee46'

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

