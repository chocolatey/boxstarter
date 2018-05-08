function Log-BoxStarterMessage {
<#
.SYNOPSIS
Logs a message to the Boxstarter Log File

.DESCRIPTION
Logs a message to the log. The message does not render on the
console. Boxstarter timestamps the log message so that the file
entry has the time the message was written. The log is located at
$Boxstarter.Log.

.Parameter Message
The message to be logged.

.LINK
https://boxstarter.org
about_boxstarter_logging

#>
    param([object[]]$message)
    if($Boxstarter.Log) {
        $fileStream = New-Object -TypeName System.IO.FileStream -ArgumentList @(
            $Boxstarter.Log,
            [system.io.filemode]::Append,
            [System.io.FileAccess]::Write,
            [System.IO.FileShare]::ReadWrite
        )
        $writer = New-Object -TypeName System.IO.StreamWriter -ArgumentList @(
            $fileStream,
            [System.Text.Encoding]::UTF8
        )
        try {
            $writer.WriteLine("[$(Get-Date -format o):::PID $pid] $message")
        }
        finally{
            $writer.Dispose()
        }
    }
}
