<#
***********************************************************************************
*   This function was written by Brian Wilhite
*   Published at http://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542
*   Distributed according to Technet Terms of Use
*   http://technet.microsoft.com/cc300389.aspx
***********************************************************************************
#>
Function Get-PendingReboot
{
<#
.SYNOPSIS
	Gets the pending reboot status on a local or remote computer.

.DESCRIPTION
	This function will query the registry on a local or remote computer and determine if the
	system is pending a reboot, from either Microsoft Patching or a Software Installation.
	For Windows 2008+ the function will query the CBS registry key as another factor in determining
	pending reboot state.  "PendingFileRenameOperations" and "Auto Update\RebootRequired" are observed
	as being consistant across Windows Server 2003 & 2008.
	
	CBServicing = Component Based Servicing (Windows 2008)
	WindowsUpdate = Windows Update / Auto Update (Windows 2003 / 2008)
	PendFileRename = PendingFileRenameOperations (Windows 2003 / 2008)

.PARAMETER ComputerName
	A single Computer or an array of computer names.  The default is localhost ($env:COMPUTERNAME).

.PARAMETER ErrorLog
	A single path to send error data to a log file.

.EXAMPLE
	PS C:\> Get-PendingReboot -ComputerName (Get-Content C:\ServerList.txt) | Format-Table -AutoSize
	
	Computer   CBServicing WindowsUpdate PendFileRename RebootPending
    --------   ----------- ------------- -------------- -------------
	DC01             False         False          False         False
	DC02             False         False          False         False
	FS01             False          True           True          True

	This example will capture the contents of C:\ServerList.txt and query the pending reboot
	information from the systems contained in the file and display the output in a table

.EXAMPLE
	PS C:\> Get-PendingReboot
	
	Computer       : WKS01
	CBServicing    : False
	WindowsUpdate  : True
	PendFileRename : False
	RebootPending  : True
	
	This example will query the local machine for pending reboot information.
	
.EXAMPLE
	PS C:\> $Servers = Get-Content C:\Servers.txt
	PS C:\> Get-PendingReboot -Computer $Servers | Export-Csv C:\PendingRebootReport.csv -NoTypeInformation
	
	This example will create a report that contains pending reboot information.

.LINK
	Component-Based Servicing:
	http://technet.microsoft.com/en-us/library/cc756291(v=WS.10).aspx
	
	PendingFileRename/Auto Update:
	http://support.microsoft.com/kb/2723674
	http://technet.microsoft.com/en-us/library/cc960241.aspx
	http://blogs.msdn.com/b/hansr/archive/2006/02/17/patchreboot.aspx

.NOTES
	Author: Brian Wilhite
	Email:  bwilhite1@carolina.rr.com
	Date:   08/29/2012
	PSVer:  2.0/3.0
#>

[CmdletBinding()]
param(
	[Parameter(Position=0,ValueFromPipeline=$true)]
	[Alias("CN","Computer")]
	[String[]]$ComputerName="$env:COMPUTERNAME",
	[String]$ErrorLog
	)

Begin
	{
		#Adjusting ErrorActionPreference to stop on all errors
		$TempErrAct = $ErrorActionPreference
		$ErrorActionPreference = "Stop"
	}#End Begin Script Block
Process
	{
		Foreach ($Computer in $ComputerName)
			{
				$Computer = $Computer.ToUpper().Trim()
				Try
					{
						#Setting pending values to false to cut down on the number of else statements
						$CBS,$WUAU,$PendFileRename,$Pending = $false, $false, $false, $false
						
						#Querying WMI for build version
						$WMI_OS = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $Computer
						
						#Making registry connection to the local/remote computer
						$RegCon = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]"LocalMachine",$Computer)
						
						#If Vista/2008 & Above query the CBS Reg Key
						If ($WMI_OS.BuildNumber -ge 6001)
							{
								$RegSubKeysCBS = $RegCon.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\").GetSubKeyNames()
								$CBSRebootPend = $RegSubKeysCBS -contains "RebootPending"
								If ($CBSRebootPend)
									{
										$CBS = $true
									}#End If ($CBSRebootPend)
									
							}#End If ($WMI_OS.BuildNumber -ge 6001)
							
						#Query WUAU from the registry
						$RegWUAU = $RegCon.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\")
						$RegWUAURebootReq = $RegWUAU.GetSubKeyNames()
						$WUAURebootReq = $RegWUAURebootReq -contains "RebootRequired"
						
						#Query PendingFileRenameOperations from the registry
						$RegSubKeySM = $RegCon.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\")
						$RegValuePFRO = $RegSubKeySM.GetValue("PendingFileRenameOperations",$null)
						
						#Closing registry connection
						$RegCon.Close()
						
						#If values from the registry are present, setting each respective variable to $true
						If ($WUAURebootReq)
							{
								$WUAU = $true
							}#End If ($WUAURebootReq)
						If ($RegValuePFRO)
							{
								$PendFileRename = $true
							}#End If ($RegValuePFRO)
						If ($CBS -or $WUAU -or $PendFileRename)
							{
								$Pending = $true
							}#End If ($CBS -or $WUAU -or $PendFileRename)
							
						#Creating $Data Custom PSObject
						$Data = New-Object -TypeName PSObject -Property @{
								Computer=$Computer
								CBServicing=$CBS
								WindowsUpdate=$WUAU
								PendFileRename=$PendFileRename
								RebootPending=$Pending
								}#End $Data Custom object
						
						#Returning $Data object in a selected order to the user
						$Data | Select-Object -Property Computer, CBServicing, WindowsUpdate, PendFileRename, RebootPending
						
					}#End Try
				Catch
					{
						Write-Warning "$Computer`: $_"
						
						#If $ErrorLog, log the file to a user specified location/path
						If ($ErrorLog)
							{
								Out-File -InputObject "$Computer`,$_" -FilePath $ErrorLog -Append
							}#End If ($ErrorLog)
							
					}#End Catch
					
			}#End Foreach ($Computer in $ComputerName)
			
	}#End Process
	
End
	{
		#Resetting ErrorActionPref
		$ErrorActionPreference = $TempErrAct
	}#End End
	
}#End Function