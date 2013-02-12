<#A Build step copies this function to bootstrapper and Helpers Directory. Only edit script in Common#>
function Write-BoxstarterMessage {
<#
.SYNOPSIS
Writes a message to the console and the log

.DESCRIPTION
Formats the message in green. This message is also logged to the 
Boxstarter log file with a timestamp.

.PARAMETER Message
The string to be logged

.PARAMETER NoLogo
If ommited, the message will be preceeded with "Boxstarter: "

.EXAMPLE
Write-BoxstarterMessage "I am logging a message."

This creates the following console output:
Boxstarter: I am Logging a Message

This will appear in the log:
[2013-02-11T00:59:44.9768457-08:00] Boxstarter: I am Logging a Message

.LINK
http://boxstarter.codeplex.com

#>
    param([String]$message, [switch]$nologo)
    if($Boxstarter.SuppressLogging){return}
    if(!$nologo){$message = "Boxstarter: $message"}
    $fmtTitle = Format-BoxStarterMessage $message
    Write-Host $fmtTitle -ForeGroundColor green
    Log-BoxStarterMessage $fmtTitle
}