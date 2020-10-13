
<#
.SYNOPSIS
    test if current session/identity is elevated 
    (a.k.a. check if we've got admin privileges)
#>
function Test-Admin {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal( $identity )
    return $principal.IsInRole( [System.Security.Principal.WindowsBuiltInRole]::Administrator )
}

<#
.SYNOPSIS
    get name of 'WellKnownSidType' in the current user's system locale
#>
function Get-LocalizedWellKnownPrincipalName {
    param (
        [Parameter(Mandatory = $true)]
        [Security.Principal.WellKnownSidType] $WellKnownSidType
    )
    $sid = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList @($WellKnownSidType, $null)
    $account = $sid.Translate([Security.Principal.NTAccount])

    return $account.Value
}

<#
.SYNOPSIS
    ensure a given folder is only writeable by administrative users

.NOTES
    we need to do this in order to mitigate privilege escalation attacks!
    
    Attack Vector 1: Boxstarter folders are added to PATH, therefore they must be protected in a way so 
    that a random user may not put arbitrary files/dlls in these folders.
    (files may be replaces with hijacked/malicious ones)
    
    Attack Vector 2: 'BuildPackages' contains Boxstarter Packages that may be installed after system reboots.
    If a user would be able to modify those packages, it would be easy to run arbitrary PowerShell code with 
    SYSTEM privileges.
    
    see Ensure-Permissions 
    https://github.com/chocolatey/choco/blob/master/nuget/chocolatey/tools/chocolateysetup.psm1
#>
function Ensure-Permissions {
    [CmdletBinding()]
    param(
        [string]$folder
    )
    Write-Debug "Ensure-Permissions"

    $currentEA = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    try {
        # get current acl
        $acl = (Get-Item $folder).GetAccessControl('Access,Owner')

        Write-Debug "Removing existing permissions."
        $acl.Access | ForEach-Object {
            Write-Debug "Remove '$($_.FileSystemRights)' for user '$($_.IdentityReference)'"
            $acl.RemoveAccessRuleAll($_) 
        }

        $inheritanceFlags = ([Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit)
        $propagationFlags = [Security.AccessControl.PropagationFlags]::None

        $rightsFullControl = [Security.AccessControl.FileSystemRights]::FullControl
        $rightsReadExecute = [Security.AccessControl.FileSystemRights]::ReadAndExecute

        Write-Output "Restricting write permissions of '$folder' to Administrators"
        $builtinAdmins = Get-LocalizedWellKnownPrincipalName -WellKnownSidType ([Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid)
        $adminsAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($builtinAdmins, $rightsFullControl, $inheritanceFlags, $propagationFlags, "Allow")
        $acl.SetAccessRule($adminsAccessRule)
        $localSystem = Get-LocalizedWellKnownPrincipalName -WellKnownSidType ([Security.Principal.WellKnownSidType]::LocalSystemSid)
        $localSystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($localSystem, $rightsFullControl, $inheritanceFlags, $propagationFlags, "Allow")
        $acl.SetAccessRule($localSystemAccessRule)
        $builtinUsers = Get-LocalizedWellKnownPrincipalName -WellKnownSidType ([Security.Principal.WellKnownSidType]::BuiltinUsersSid)
        $usersAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($builtinUsers, $rightsReadExecute, $inheritanceFlags, $propagationFlags, "Allow")
        $acl.SetAccessRule($usersAccessRule)

        Write-Debug "Set Owner to Administrators"
        $builtinAdminsSid = New-Object System.Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
        $acl.SetOwner($builtinAdminsSid)

        Write-Debug "Removing inheritance with no copy"
        $acl.SetAccessRuleProtection($true, $false)

        # enact the changes against the actual
        (Get-Item $folder).SetAccessControl($acl)

    }
    catch {
        Write-Warning $_.Exception
        Write-Warning "Not able to set permissions for $folder."
    }
    $ErrorActionPreference = $currentEA
}

function Install-Boxstarter($here, $ModuleName, $installArgs = "") {

    if (!(Test-Admin)) {
        throw "Installation of Boxstarter requires Administrative permissions. Please run from elevated prompt."
    }

    $boxstarterPath = Join-Path $env:ProgramData Boxstarter
    if (!(test-Path $boxstarterPath)) {
        New-Item -ItemType Directory $boxstarterPath | Out-Null
    }
    $packagePath = Join-Path $boxstarterPath BuildPackages
    if (!(test-Path $packagePath)) {
        New-Item -ItemType Directory $packagePath | Out-Null
    }
    foreach ($ModulePath in (Get-ChildItem $here | Where-Object { $_.PSIsContainer })) {
        $target = Join-Path $boxstarterPath $modulePath.BaseName
        if (test-Path $target) {
            Remove-Item $target -Recurse -Force
        }
    }
    Copy-Item "$here\*" $boxstarterPath -Recurse -Force -Exclude ChocolateyInstall.ps1, Setup.*

    # set permissions to mitigate possible privilege escalation
    Ensure-Permissions -folder $boxstarterPath

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
            New-Item -ItemType Directory $startMenu | Out-Null
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
