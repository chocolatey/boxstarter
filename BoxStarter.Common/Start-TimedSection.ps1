function Start-TimedSection {
<#
.SYNOPSIS
Begins a timed section

.DESCRIPTION
A timed section is a portion of script that is timed. Used
with Stop-TimedSection, the beginning and end of the section
are logged to both the console and the log along with the
amount of time elapsed.

The function returns a guid that is used to identify the
section when stopping it.

.PARAMETER SectionName
The Title or Label of the section being timed. This string
is used in the logging to identify the section.

.PARAMETER Verbose
Instructs Start-TimedSection to write to the Verbose stream. Although
this will always log messages to the Boxstarter log, it will only log
to the console if the session's VerbosePreference is set to capture
the Verbose stream or the -Verbose switch was set when calling
Install-BoxstarterPackage.

.EXAMPLE
$session=Start-TimedSection "My First Section"
Stop-TimedSection $session

This creates a block as follows:

+ Boxstarter starting My First Section

Some stuff happens here.

+ Boxstarter finished My First Section 00:00:00.2074282

.EXAMPLE
Timed Sections can be nested or staggered. You can have
multiple sections running at once.

$session=Start-TimedSection "My First Section"
$innerSession=Start-TimedSection "My Inner Section"
Stop-TimedSection $innerSession
Stop-TimedSection $session

This creates a block as follows:

+ Boxstarter starting My First Section

Some stuff happens here.

++ Boxstarter starting My Inner Section

Some inner stuff happens here.

++ Boxstarter finished My Inner Section 00:00:00.1074282

Some more stuff happens here.

+ Boxstarter finished My First Section 00:00:00.2074282

Note that the number of '+' chars indicate nesting level.

.EXAMPLE
$session=Start-TimedSection "My First Section" -Verbose
Stop-TimedSection $session

This will write the start and finish messages to the
Boxstarter log but will not write to the console unless the
user has the the VerbosePreference variable or used the
Verbose switch of Install-BoxstarterPackage.

.NOTES
If the SuppressLogging setting of the $Boxstarter variable is true,
logging messages will be suppressed and not sent to the console or the
log.

.LINK
https://boxstarter.org
Stop-TimedSection
about_boxstarter_logging
#>
    param(
        [string]$sectionName,
        [switch]$Verbose)
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $guid = [guid]::NewGuid().ToString()
    $timerEntry=@{title=$sectionName;stopwatch=$stopwatch;verbose=$Verbose}
    if(!$script:boxstarterTimers) {$script:boxstarterTimers=@{}}
    $boxstarterTimers.$guid=$timerEntry
    $padCars="".PadLeft($boxstarterTimers.Count,"+")
    Write-BoxstarterMessage "$padCars Boxstarter starting $sectionName" -NoLogo -Verbose:$Verbose
    return $guid
}
