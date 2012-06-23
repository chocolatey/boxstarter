###########################################################################" 
 #  
 # 
 # NAME: PinnedApplications.psm1 
 #  
 # AUTHOR: Jan Egil Ring, Crayon 
 # 
 # DATE  : 06.08.2010  
 #  
 # COMMENT: Module with the ability to pin and unpin programs from the taskbar and the Start-menu in Windows 7 and Windows Server 2008 R2. 
 # 
 # This module are based on the Add-PinnedApplication script created by Ragnar Harper and Kristian Svantorp: 
 # http://blogs.technet.com/kristian/archive/2009/04/24/nytt-script-pin-to-taskbar.aspx 
 # http://blog.crayon.no/blogs/ragnar/archive/2009/04/17/pin-applications-to-windows-7-taskbar.aspx 
 # 
 # Johan Akerstrom`s blog: http://cosmoskey.blogspot.com 
 # 
 # For more information, see the following blog post: 
 # http://blog.crayon.no/blogs/janegil/archive/2010/02/26/pin-and-unpin-applications-from-the-taskbar-and-start-menu-using-windows-powershell.aspx 
 # 
 # VERSION HISTORY: 
 # 1.0 17.04.2009 - Initial release by Ragnar Harper and Kristian Svantorp 
 # 1.1 26.02.2010 - Update by Jan Egil Ring. Added the capability to unpin applications. 
 # 1.2 06.08.2010 - Update by Johan Akerstrom. Added full MUI support. 
 #  
 ###########################################################################" 
 
 
function Set-PinnedApplication 
{ 
<#  
.SYNOPSIS  
This function are used to pin and unpin programs from the taskbar and Start-menu in Windows 7 and Windows Server 2008 R2 
.DESCRIPTION  
The function have to parameteres which are mandatory: 
Action: PinToTaskbar, PinToStartMenu, UnPinFromTaskbar, UnPinFromStartMenu 
FilePath: The path to the program to perform the action on 
.EXAMPLE 
Set-PinnedApplication -Action PinToTaskbar -FilePath "C:\WINDOWS\system32\notepad.exe" 
.EXAMPLE 
Set-PinnedApplication -Action UnPinFromTaskbar -FilePath "C:\WINDOWS\system32\notepad.exe" 
.EXAMPLE 
Set-PinnedApplication -Action PinToStartMenu -FilePath "C:\WINDOWS\system32\notepad.exe" 
.EXAMPLE 
Set-PinnedApplication -Action UnPinFromStartMenu -FilePath "C:\WINDOWS\system32\notepad.exe" 
#>  
       [CmdletBinding()] 
       param( 
      [Parameter(Mandatory=$true)][string]$Action,  
      [Parameter(Mandatory=$true)][string]$FilePath 
       ) 
       if(-not (test-path $FilePath)) {  
           throw "FilePath does not exist."   
    } 
    
       function InvokeVerb { 
           param([string]$FilePath,$verb) 
        $verb = $verb.Replace("&","") 
        $path= split-path $FilePath 
        $shell=new-object -com "Shell.Application"  
        $folder=$shell.Namespace($path)    
        $item = $folder.Parsename((split-path $FilePath -leaf)) 
        $itemVerb = $item.Verbs() | ? {$_.Name.Replace("&","") -eq $verb} 
        if($itemVerb -eq $null){ 
            write-host "Verb $verb not found. It may have already been pinned"             
        } else { 
            $itemVerb.DoIt() 
        } 
            
       } 
    function GetVerb { 
        param([int]$verbId) 
        try { 
            $t = [type]"CosmosKey.Util.MuiHelper" 
        } catch { 
            $def = [Text.StringBuilder]"" 
            [void]$def.AppendLine('[DllImport("user32.dll")]') 
            [void]$def.AppendLine('public static extern int LoadString(IntPtr h,uint id, System.Text.StringBuilder sb,int maxBuffer);') 
            [void]$def.AppendLine('[DllImport("kernel32.dll")]') 
            [void]$def.AppendLine('public static extern IntPtr LoadLibrary(string s);') 
            add-type -MemberDefinition $def.ToString() -name MuiHelper -namespace CosmosKey.Util             
        } 
        if($global:CosmosKey_Utils_MuiHelper_Shell32 -eq $null){         
            $global:CosmosKey_Utils_MuiHelper_Shell32 = [CosmosKey.Util.MuiHelper]::LoadLibrary("shell32.dll") 
        } 
        $maxVerbLength=255 
        $verbBuilder = new-object Text.StringBuilder "",$maxVerbLength 
        [void][CosmosKey.Util.MuiHelper]::LoadString($CosmosKey_Utils_MuiHelper_Shell32,$verbId,$verbBuilder,$maxVerbLength) 
        return $verbBuilder.ToString() 
    } 
 
    $verbs = @{  
        "PintoStartMenu"=5381 
        "UnpinfromStartMenu"=5382 
        "PintoTaskbar"=5386 
        "UnpinfromTaskbar"=5387 
    } 
        
    if($verbs.$Action -eq $null){ 
           Throw "Action $action not supported`nSupported actions are:`n`tPintoStartMenu`n`tUnpinfromStartMenu`n`tPintoTaskbar`n`tUnpinfromTaskbar" 
    } 
    InvokeVerb -FilePath $FilePath -Verb $(GetVerb -VerbId $verbs.$action) 
} 
 
Export-ModuleMember Set-PinnedApplication