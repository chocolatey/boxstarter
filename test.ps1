
$scriptPath = (Split-Path -parent $MyInvocation.MyCommand.path)
. $scriptPath\utilities.ps1
Set-FileAssociation ".txt" "$env:programfiles\Sublime Text 2\sublime_text.exe"
