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
    CCMClientSDK = SCCM 2012 Clients only (DetermineIfRebootPending method) otherwise $null value
    PendFileRename = PendingFileRenameOperations (Windows 2003 / 2008)

.PARAMETER ComputerName
    A single Computer or an array of computer names.  The default is localhost ($env:COMPUTERNAME).

.PARAMETER ErrorLog
    A single path to send error data to a log file.

.EXAMPLE
    PS C:\> Get-PendingReboot
	
    Computer           : WKS01
    CBServicing        : False
    WindowsUpdate      : False
    CCMClientSDK       : False
    PendComputerRename : False
    PendFileRename     : False
    PendFileRenVal     :
    RebootPending      : False
	
    This example will query the local machine for pending reboot information.
	
.EXAMPLE
    PS C:\> $Servers = Get-Content C:\Servers.txt
    PS C:\> Get-PendingReboot -Computer $Servers | Export-Csv C:\PendingRebootReport.csv -NoTypeInformation
	
    This example will create a report that contains pending reboot information.

.LINK
    Hey, Scripting Guy!:
    http://blogs.technet.com/b/heyscriptingguy/archive/2013/06/10/determine-pending-reboot-status-powershell-style-part-1.aspx
    http://blogs.technet.com/b/heyscriptingguy/archive/2013/06/10/determine-pending-reboot-status-powershell-style-part-2.aspx

    Component-Based Servicing:
    http://technet.microsoft.com/en-us/library/cc756291(v=WS.10).aspx
	
    PendingFileRename/Auto Update:
    http://support.microsoft.com/kb/2723674
    http://technet.microsoft.com/en-us/library/cc960241.aspx
    http://blogs.msdn.com/b/hansr/archive/2006/02/17/patchreboot.aspx

    SCCM 2012/CCM_ClientSDK:
    http://msdn.microsoft.com/en-us/library/jj902723.aspx

.NOTES
    Author:  Brian Wilhite
    Email:   bwilhite@microsoft.com
    Date:    08/29/2012
    PSVer:   2.0/3.0/4.0
    Updated: 06NOV2013
    UpdNote: Added CCMClient property - Used with SCCM 2012 Clients only
             Added ValueFromPipelineByPropertyName=$true to the ComputerName Parameter
             Removed $Data variable from the PSObject - it is not needed
             Bug with the way CCMClientSDK returned null value if it was false
             Removed unneeded variables
             Added PendFileRenVal - Contents of the PendingFileRenameOperations Reg Entry
             Removed .Net Registry connection, replaced with WMI StdRegProv
             Added ComputerPendingRename
#>

[CmdletBinding()]
param(
	[Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
	[Alias("CN","Computer")]
	[String[]]$ComputerName="$env:COMPUTERNAME",
	[String]$ErrorLog
	)

Begin {  }## End Begin Script Block
Process {
	Foreach ($Computer in $ComputerName) {
        Try {
	        ## Setting pending values to false to cut down on the number of else statements
	        $CompPendRen,$PendFileRename,$Pending,$SCCM = $false,$false,$false,$false
                        
	        ## Setting CBSRebootPend to null since not all versions of Windows has this value
	        $CBSRebootPend = $null
						
	        ## Querying WMI for build version
	        $WMI_OS = Get-WmiObject -Class Win32_OperatingSystem -Property BuildNumber, CSName -ComputerName $Computer -ErrorAction Stop

	        ## Making registry connection to the local/remote computer
	        $HKLM = [UInt32] "0x80000002"
	        $WMI_Reg = [WMIClass] "\\$Computer\root\default:StdRegProv"
						
	        ## If Vista/2008 & Above query the CBS Reg Key
	        If ($WMI_OS.BuildNumber -ge 6001) {
		        $RegSubKeysCBS = $WMI_Reg.EnumKey($HKLM,"SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\")
		        $CBSRebootPend = $RegSubKeysCBS.sNames -contains "RebootPending"
									
	        }## End If ($WMI_OS.BuildNumber -ge 6001)
							
	        ## Query WUAU from the registry
	        $RegWUAURebootReq = $WMI_Reg.EnumKey($HKLM,"SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\")
	        $WUAURebootReq = $RegWUAURebootReq.sNames -contains "RebootRequired"
						
	        ## Query PendingFileRenameOperations from the registry
	        $RegSubKeySM = $WMI_Reg.GetMultiStringValue($HKLM,"SYSTEM\CurrentControlSet\Control\Session Manager\","PendingFileRenameOperations")
	        $RegValuePFRO = $RegSubKeySM.sValue

            ## Query ComputerName and ActiveComputerName from the registry
            $ActCompNm = $WMI_Reg.GetStringValue($HKLM,"SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName\","ComputerName")            
            $CompNm = $WMI_Reg.GetStringValue($HKLM,"SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName\","ComputerName")
            If ($ActCompNm -ne $CompNm) {
                $CompPendRen = $true

            }## End If ($ActCompNm -ne $CompNm)
						
	        ## If PendingFileRenameOperations has a value set $RegValuePFRO variable to $true
	        If ($RegValuePFRO) {
		        $PendFileRename = $true

	        }## End If ($RegValuePFRO)

	        ## Determine SCCM 2012 Client Reboot Pending Status
	        ## To avoid nested 'if' statements and unneeded WMI calls to determine if the CCM_ClientUtilities class exist, setting EA = 0
	        $CCMClientSDK = $null
            $CCMSplat = @{
                NameSpace='ROOT\ccm\ClientSDK'
                Class='CCM_ClientUtilities'
                Name='DetermineIfRebootPending'
                ComputerName=$Computer
                ErrorAction='SilentlyContinue'
                }
            $CCMClientSDK = Invoke-WmiMethod @CCMSplat
	        If ($CCMClientSDK) {
                If ($CCMClientSDK.ReturnValue -ne 0) {
			        Write-Warning "Error: DetermineIfRebootPending returned error code $($CCMClientSDK.ReturnValue)"
                            
		        }## End If ($CCMClientSDK -and $CCMClientSDK.ReturnValue -ne 0)

		        If ($CCMClientSDK.IsHardRebootPending -or $CCMClientSDK.RebootPending) {
			        $SCCM = $true

		        }## End If ($CCMClientSDK.IsHardRebootPending -or $CCMClientSDK.RebootPending)

            }## End If ($CCMClientSDK)
            Else {
                $SCCM = $null

            }## End Else

            ## Creating Custom PSObject and Select-Object Splat
            $SelectSplat = @{
                Property=(
                    'Computer',
                    'CBServicing',
                    'WindowsUpdate',
                    'CCMClientSDK',
                    'PendComputerRename',
                    'PendFileRename',
                    'PendFileRenVal',
                    'RebootPending'
                )}
	        New-Object -TypeName PSObject -Property @{
			        Computer=$WMI_OS.CSName
			        CBServicing=$CBSRebootPend
			        WindowsUpdate=$WUAURebootReq
			        CCMClientSDK=$SCCM
                                PendComputerRename=$CompPendRen
			        PendFileRename=$PendFileRename
			        PendFileRenVal=$RegValuePFRO
			        RebootPending=($CompPendRen -or $CBSRebootPend -or $WUAURebootReq -or $SCCM -or $PendFileRename)
			        } | Select-Object @SelectSplat

        } Catch {
			Write-Warning "$Computer`: $_"
						
			## If $ErrorLog, log the file to a user specified location/path
			If ($ErrorLog) {
				Out-File -InputObject "$Computer`,$_" -FilePath $ErrorLog -Append

			}## End If ($ErrorLog)
							
		}## End Catch
					
	}## End Foreach ($Computer in $ComputerName)
			
}## End Process
	
End {  }## End End
	
}## End Function Get-PendingReboot