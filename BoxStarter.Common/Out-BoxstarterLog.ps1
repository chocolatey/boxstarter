function Enter-BoxstarterLogable{
<#
.SYNOPSIS
Logs the output and error streams of the script to the
console and Boxstarter log.

.DESCRIPTION
Boxstarter runs the provided script and redirects the
standard output and standard error streams to the host
console and to the Boxstarter log. This will include both
PowerShell Write-Output and errors as well as the output
from any standard command line executables that use
standard output and error streams.

.PARAMETER script
The script to execute.

.EXAMPLE
Enter-BoxstarterLogable{
    Get-Process Chrome
    Netstat
}

This sends both the out put of the PowerShell Get-Process
cmdlet and the Netstat command line utility to the screen
as well as th boxstarter log.

.LINK
https://boxstarter.org
about_boxstarter_logging

#>
    param([ScriptBlock] $script)

    & ($script) 2>&1 | Out-BoxstarterLog
}

function Out-BoxstarterLog {
<#
.SYNOPSIS
Logs provided text or objects to the console and
Boxstarter log.

.DESCRIPTION
This is essentially identical to Tee-Object with the PS 3.0
only parameter -Append. This will work in either PS 2.0 or
PS 3.0.

.PARAMETER object
Object to log.

.EXAMPLE
Out-BoxstarterLog "This can be seen on the screen and in the log file"

.EXAMPLE
"This can be seen on the screen and in the log file" | Out-BoxstarterLog

.LINK
https://boxstarter.org
about_boxstarter_logging

#>
    param(
        [Parameter(position=0,ValueFromPipeline=$True)]
        [object]$object,
        [switch]$Quiet
    )

    process {
        if(!$Quiet -and !$Boxstarter.SuppressLogging){Write-Host $object}
        if($object){
            Log-BoxstarterMessage $object
        }
    }
}
