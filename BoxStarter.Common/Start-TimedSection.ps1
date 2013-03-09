function Start-TimedSection {
<#
.SYNOPSIS
Begins a timed section

.DESCRIPTION
A timed section is a portion of script that is timed. Used 
with Stop-TimedSection, the beginning and end of the section 
are loged to both the console and the log along with the 
amount of time elapsed.

The function returns a guid that is used to identify the 
section when stopping it.

.PARAMETER SectionName
The Title or Label of the section being timed. This string 
is used in the logging to identify the section.

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

.NOTES
If the SuppressLogging setting of the $Boxstarter variable is true, 
logging mesages will be suppresed and not sent to the console or the 
log.

.LINK
http://boxstarter.codeplex.com
Stop-TimedSection
about_boxstarter_logging
#>
    param([string]$sectionName)
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $guid = [guid]::NewGuid().ToString()
    $timerEntry=@{title=$sectionName;stopwatch=$stopwatch}
    if(!$script:boxstarterTimers) {$script:boxstarterTimers=@{}}
    $boxstarterTimers.$guid=$timerEntry
    $padCars="".PadLeft($boxstarterTimers.Count,"+")
    Write-BoxstarterMessage "$padCars Boxstarter starting $sectionName" -NoLogo 
    return $guid
}