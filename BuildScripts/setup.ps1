function Install-Boxstarter($here, $ModuleName, $installArgs = "") {
    $boxstarterPath = Join-Path $env:ProgramData Boxstarter
    if(!(test-Path $boxstarterPath)){
        mkdir $boxstarterPath
    }
    $packagePath=Join-Path $boxstarterPath BuildPackages
    if(!(test-Path $packagePath)){
        mkdir $packagePath
    }
    foreach($ModulePath in (Get-ChildItem $here | Where-Object { $_.PSIsContainer })){
        $target=Join-Path $boxstarterPath $modulePath.BaseName
        if(test-Path $target){
            Remove-Item $target -Recurse -Force
        }
    }
    Copy-Item "$here\*" $boxstarterPath -Recurse -Force -Exclude ChocolateyInstall.ps1, Setup.*

    PersistBoxStarterPathToEnvironmentVariable "PSModulePath" $boxstarterPath
    PersistBoxStarterPathToEnvironmentVariable "Path" $boxstarterPath
    $binPath =  "$here\..\..\..\bin"
    $boxModule=Get-Module Boxstarter.Chocolatey
    if($boxModule) {
        if($boxModule.Path -like "$env:LOCALAPPDATA\Apps\*") {
            $clickonce=$true
        }
    }
    if(!$clickonce){
        Import-Module "$boxstarterPath\$ModuleName" -DisableNameChecking -Force -ErrorAction SilentlyContinue
    }
    $successMsg = @"
The $ModuleName Module has been copied to $boxstarterPath and added to your Module path.
You will need to open a new console for the path to be visible.
Use 'Get-Module Boxstarter.* -ListAvailable' to list all Boxstarter Modules.
To list all available Boxstarter Commands, use:
PS:>Import-Module $ModuleName
PS:>Get-Command -Module Boxstarter.*

To find more info visit https://Boxstarter.org or use:
PS:>Import-Module $ModuleName
PS:>Get-Help Boxstarter
"@
    Write-Host $successMsg

    if($ModuleName -eq "Boxstarter.Chocolatey" -and !$env:appdata.StartsWith($env:windir)) {
        $desktop = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::CommonDesktopDirectory)
        $startMenu = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::CommonStartMenu)
        $startMenu += "\Programs\Boxstarter"
        if(!(Test-Path $startMenu)){
            mkdir $startMenu
        }
        $target="powershell.exe"
        $targetArgs="-ExecutionPolicy bypass -NoExit -Command `"&'$boxstarterPath\BoxstarterShell.ps1'`""

		if($installArgs -inotcontains "nodesktopicon") {
			$link = Join-Path $desktop "Boxstarter Shell.lnk"
			Create-Shortcut $link $target $targetArgs $boxstarterPath
		}
        $link = Join-Path $startMenu "Boxstarter Shell.lnk"
        Create-Shortcut $link $target $targetArgs $boxstarterPath

        Set-Content -Path "$binPath\BoxstarterShell.bat" -Force -Value "$target $TargetArgs"
    }
}

function Uninstall-Boxstarter ($here, $ModuleName, $installArgs = "") {

    if ($ModuleName -eq "Boxstarter.Chocolatey" -and !$env:appdata.StartsWith($env:windir)) {
        $startMenu = Join-Path -Path ([Environment]::GetFolderPath('CommonPrograms')) -ChildPath "Boxstarter"

        if (Test-Path $startMenu) {
            Write-Verbose "Removing '$startMenu' menu folder"
            Remove-Item -Path $startMenu -Recurse -Force
        }

        $desktopShortcut = Join-Path -Path ([Environment]::GetFolderPath('CommonDesktop')) -ChildPath "Boxstarter Shell.lnk"
        if (Test-Path $desktopShortcut) {
            Write-Verbose "Removing '$desktopShortcut'"
            Remove-Item -Path $desktopShortcut -Force
        }
    }
}

function Create-Shortcut($location, $target, $targetArgs, $boxstarterPath) {
    $wshshell = New-Object -ComObject WScript.Shell
    $lnk = $wshshell.CreateShortcut($location)
    $lnk.TargetPath = $target
    $lnk.Arguments = "$targetArgs"
    $lnk.WorkingDirectory = $boxstarterPath
    $lnk.IconLocation="$boxstarterPath\BoxLogo.ico"
    $lnk.Save()

    #This adds a bit to the shortcut link that causes it to open with admin privileges
	$tempFile = "$env:temp\TempShortcut.lnk"

	$writer = new-object System.IO.FileStream $tempFile, ([System.IO.FileMode]::Create)
	$reader = new-object System.IO.FileStream $location, ([System.IO.FileMode]::Open)

	while ($reader.Position -lt $reader.Length)
	{
		$byte = $reader.ReadByte()
		if ($reader.Position -eq 22) {
			$byte = 34
		}
		$writer.WriteByte($byte)
	}

	$reader.Close()
	$writer.Close()

	Move-Item -Path $tempFile $location -Force
}
function PersistBoxStarterPathToEnvironmentVariable($variableName, $boxstarterPath){
    # Remove user scoped vars from previous releases
    $userValue = [Environment]::GetEnvironmentVariable($variableName, 'User')
    if($userValue){
        $userValues=($userValue -split ';' | Where-Object { !($_.ToLower() -match "\\boxstarter$")}) -join ';'
    }
    elseif($variableName -eq "PSModulePath") {
        $userValues = [environment]::getfolderpath("mydocuments")
        $userValues +="\WindowsPowerShell\Modules"
    }
    [Environment]::SetEnvironmentVariable($variableName, $userValues, 'User')

    $value = [Environment]::GetEnvironmentVariable($variableName, 'Machine')
    if($value){
        $values=($value -split ';' | Where-Object { !($_.ToLower() -match "\\boxstarter$")}) -join ';'
        $values="$boxstarterPath;$values"
    }
    elseif($variableName -eq "PSModulePath") {
        $values = "$boxstarterPath;"
        $values += [environment]::getfolderpath("ProgramFiles")
        $values +="\WindowsPowerShell\Modules"
    }
    else {
        $values ="$boxstarterPath"
    }

    [Environment]::SetEnvironmentVariable($variableName, $values, 'Machine')
    $varValue = Get-Content env:\$variableName
    $varValue = "$boxstarterPath;$varValue"
    Set-Content env:\$variableName -value $varValue
}
