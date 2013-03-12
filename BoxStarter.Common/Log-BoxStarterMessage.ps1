function Log-BoxStarterMessage {
<#
.SYNOPSIS
Logs a message to the Boxstarter Log File

.DESCRIPTION
Logs a message to the log. The message does not render on the 
console. Boxstarter timestamps the log message so that the file 
entry has the time the message was writen. The log is located at 
$Boxstarter.Log.

.Parameter Message
The message to be logged.

.LINK
http://boxstarter.codeplex.com
about_boxstarter_logging

#>
    param([object[]]$message)
    if($Boxstarter.Log) {
        "[$(Get-Date -format o)] $message" | out-file $Boxstarter.Log -append
    }
}