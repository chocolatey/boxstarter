$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(get-module Boxstarter.Chocolatey){Remove-Module boxstarter.Chocolatey}
Resolve-Path $here\..\Boxstarter.Common\*.ps1 | 
    % { . $_.ProviderPath }
Resolve-Path $here\..\Boxstarter.Bootstrapper\*.ps1 | 
    % { . $_.ProviderPath }

$Boxstarter.BaseDir=(split-path -parent $here)
$Boxstarter.SuppressLogging=$true
Resolve-Path $here\..\Boxstarter.Chocolatey\*.ps1 | 
    % { . $_.ProviderPath }

Describe "New-BoxstarterPackage" {
    Context "When No Path is provided" {

    }
}