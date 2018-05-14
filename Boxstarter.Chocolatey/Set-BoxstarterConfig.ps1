function Set-BoxStarterConfig {
<#
.SYNOPSIS
Sets persist-able Boxstarter configuration settings.

.DESCRIPTION
Boxstarter stores configuration data in an xml file in the Boxstarter base
directory. The Set-BoxstarterConfig function is a convenience function
for changing those settings.

.Parameter LocalRepo
The path where Boxstarter will search for local packages.

.Parameter NugetSources
A semicolon delimited list of NuGet Feed URLs where Boxstarter will search for packages

.LINK
https://boxstarter.org
about_boxstarter_chocolatey
about_boxstarter_variable_in_chocolatey
Get-BoxstarterConfig
#>
    [CmdletBinding()]
    param([string]$LocalRepo, [string]$NugetSources)

    [xml]$configXml = Get-Content (Join-Path $Boxstarter.BaseDir BoxStarter.config)

    if($NugetSources){
        $boxstarter.NugetSources = $configXml.config.NugetSources = $NugetSources
    }
    if($LocalRepo){
        if($configXml.config.LocalRepo -eq $null) {
            $localRepoElement = $configXml.CreateElement("LocalRepo")
            $configXml.config.AppendChild($localRepoElement) | Out-Null
        }
        $boxstarter.LocalRepo = $configXml.config.LocalRepo = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LocalRepo)
    }

    $configXml.Save((Join-Path $Boxstarter.BaseDir BoxStarter.config))
}
