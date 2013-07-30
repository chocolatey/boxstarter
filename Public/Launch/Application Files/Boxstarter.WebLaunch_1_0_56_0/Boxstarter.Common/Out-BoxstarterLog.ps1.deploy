function Enter-BoxstarterLogable{
<#
.SYNOPSIS
Logs the output and error streams of the script to the 
console and Boxstarter log.

.DESCRIPTION
Boxstarter runs the provided script and redirects the 
standard output and standard error streams to the host
console and to the Boxstarter log. This will include both
powershell write-output and errors as well as the output
from any standard commandline executables that use 
standard output and error streams.

.PARAMETER script
The script to execute.

.EXAMPLE
Enter-BoxstarterLogable{
    Get-Process Chrome
    Netstat
}

This sends both the out put of the powershemm Get-Process
cmdlet and the Netstat command line utility to the screen
as well as th boxstarter log.

.LINK
http://boxstarter.codeplex.com
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
This is essentially identical to Tee-Object wih the PS 3.0
only parameter -Append. This will work in either PS 2.0 or
PS 3.0.

.PARAMETER object
Object to log.

.EXAMPLE
Out-BoxstarterLog "This can be seen on the screen and in the log file"

.EXAMPLE
"This can be seen on the screen and in the log file" | Out-BoxstarterLog

.LINK
http://boxstarter.codeplex.com
about_boxstarter_logging

#>    
    param(
        [Parameter(position=0,Mandatory=$True,ValueFromPipeline=$True)]
        [object]$object
    )

    process {
        write-host $object
        if($Boxstarter -and $BoxStarter.Log){
            $object >> $Boxstarter.Log            
        }
    }
}
