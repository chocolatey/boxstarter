function Get-BoxStarterConfig {
<#
.SYNOPSIS
Retrieves persisted Boxstarter configuration settings.

.DESCRIPTION
Boxstarter stores configuration data in an xml file in the Boxstarter base
directory. The Get-BoxstarterConfig function is a convenience function
for reading those settings.

.LINK
http://boxstarter.codeplex.com
about_boxstarter_chocolatey
about_boxstarter_variable_in_chocolatey
Set-BoxstarterConfig
#>    
    [xml]$configXml = Get-Content (Join-Path $Boxstarter.BaseDir BoxStarter.config)
    if($configXml.config.LocalRepo -ne $null){
        $localRepo=$configXml.config.LocalRepo
    } 
    else {
        if($Boxstarter.baseDir){
            $localRepo=(Join-Path $Boxstarter.baseDir BuildPackages)
        }
    }
    return @{
        LocalRepo=$localRepo;
        NugetSources=$configXml.config.NugetSources;
        ChocolateyRepo=$configXml.config.ChocolateyRepo;
        ChocolateyPackage=$configXml.config.ChocolateyPackage
    }
}