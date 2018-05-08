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
If omitted, the message will be preceded with "Boxstarter: "

.PARAMETER Color
Specifies a foreground color to use for the message. Green is the
default.

.PARAMETER Verbose
Instructs Write-Boxstarter to write to the Verbose stream. Although
this will always log messages to the Boxstarter log, it will only log
to the console if the session's VerbosePreference is set to capture
the Verbose stream or the -Verbose switch was set when calling
Install-BoxstarterPackage.

.EXAMPLE
Write-BoxstarterMessage "I am logging a message."

This creates the following console output:
Boxstarter: I am Logging a Message

This will appear in the log:
[2013-02-11T00:59:44.9768457-08:00] Boxstarter: I am Logging a Message

.EXAMPLE
Write-BoxstarterMessage "I am logging a message." -Verbose

This outputs to the console via the Verbose stream if the session's
VerbosePreference is set to capture the Verbose stream or the
-Verbose switch was set when calling Install-BoxstarterPackage.

This will appear in the log:
[2013-02-11T00:59:44.9768457-08:00] Boxstarter: I am Logging a Message

.NOTES
If the SuppressLogging setting of the $Boxstarter variable is true,
logging messages will be suppressed and not sent to the console or the
log.

.LINK
https://boxstarter.org
about_boxstarter_logging

#>
    param(
        [String]$message,
        [switch]$nologo,
        [ConsoleColor]$color=[ConsoleColor]::green,
        [switch]$Verbose
    )
    if($global:Boxstarter.ProgressArgs -and !$Verbose) {
        $a=$global:Boxstarter.ProgressArgs
        Write-Progress @a -CurrentOperation $message
    }
    if(!$nologo){$message = "Boxstarter: $message"}
    $fmtTitle = Format-BoxStarterMessage $message
    Log-BoxstarterMessage $fmtTitle
    if($Verbose){
        Write-Verbose $fmtTitle
    }
    else {
        #Boxstarter has a Write-host proxy function and it ensures all is logged
        if(!$Boxstarter.SuppressLogging){Write-Host $fmtTitle -ForeGroundColor $color}
    }
}
