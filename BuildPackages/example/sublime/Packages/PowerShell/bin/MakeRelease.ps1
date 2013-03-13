param([switch]$DontUpload=$False)

$here = $MyInvocation.MyCommand.Definition
$here = split-path $here -parent
$root = resolve-path (join-path $here "..")

push-location $root
	remove-item ".\dist" -recurse -force
	# Ensure MANIFEST reflects all changes to file system.
	remove-item ".\MANIFEST" -erroraction silentlycontinue
	start-process "python" -argumentlist ".\setup.py","spa" -NoNewWindow -Wait

	(get-item ".\dist\PowerShell.sublime-package").fullname | clip.exe
pop-location

if (-not $DontUpload) {
	start-process "https://bitbucket.org/guillermooo/powershell/downloads"
}
