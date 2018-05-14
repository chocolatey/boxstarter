function Invoke-BoxstarterFromTask($Command) {
<#
.SYNOPSIS
Runs the normal Chocolatey command as a scheduled task.

.DESCRIPTION
Creates the script necessary for a scheduled task to run the given command. The scheduled
task will run immediately.

.PARAMETER Command
A Chocolatey command to execute within a scheduled task. For example "cinst fiddler".

.EXAMPLE
A Chocolatey command

Invoke-BoxstarterFromTask "cinst rsat"

.LINK
https://boxstarter.org
about_boxstarter_chocolatey
about_boxstarter_variable_in_chocolatey
Invoke-Chocolatey
#>
    Invoke-FromTask @"
        Import-Module $($boxstarter.BaseDir)\boxstarter.chocolatey\Boxstarter.chocolatey.psd1 -DisableNameChecking
        $(Serialize-BoxstarterVars)
        `$global:Boxstarter.Log = `$null
        `$global:Boxstarter.DisableRestart = `$true
        Export-BoxstarterVars
        `$env:BoxstarterSourcePID = $PID
        . $Command
"@ -DotNetVersion "v4.0.30319"
}

