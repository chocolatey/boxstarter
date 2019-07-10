Function Set-BoxstarterPageFile {
<#
    .SYNOPSIS
        This can be used to manage the Windows page file.
    .DESCRIPTION
        This can be used to manage the Windows page file.
    .PARAMETER InitialSize
        Initial size of the page file.
    .PARAMETER MaximumSize
        Maximum size of the page file.
    .PARAMETER DriveLetter
        The drive used for the holding the page file.
    .PARAMETER SystemManagedSize
        Allow Windows to manage the page files.
    .PARAMETER None        
        Disable the use of the page file.
    .PARAMETER Reboot      
        Reboot the computer so that configuration changes take effect.
    .EXAMPLE
        C:\PS> Set-PageFile -InitialSize 1024 -MaximumSize 4096 -DriveLetter "C","D"
 
        Execution Results: Set page file size on "C" successful.
        Execution Results: Set page file size on "D:" successful.
 
        Name            InitialSize(MB) MaximumSize(MB)
        ----            --------------- ---------------
        C:\pagefile.sys            1024            4096
        D:\pagefile.sys            1024            4096
        E:\pagefile.sys            2048            4096
#>
    [cmdletbinding(SupportsShouldProcess,DefaultParameterSetName="SetPageFileSize")]
    Param
    (
        [Parameter(Mandatory,ParameterSetName="SetPageFileSize")]
        [Alias('is')]
        [Int32]$InitialSize,
 
        [Parameter(Mandatory,ParameterSetName="SetPageFileSize")]
        [Alias('ms')]
        [Int32]$MaximumSize,
 
        [Parameter(Mandatory)]
        [Alias('dl')]
        [ValidatePattern('^[A-Z]$')]
        [String[]]$DriveLetter,
 
        [Parameter(Mandatory,ParameterSetName="None")]
        [Switch]$None,
 
        [Parameter(Mandatory,ParameterSetName="SystemManagedSize")]
        [Switch]$SystemManagedSize,
 
        [Parameter()]
        [Switch]$Reboot
    )
Begin {}
Process {
    If($PSCmdlet.ShouldProcess("Setting the virtual memory page file size")) {
        $DriveLetter | ForEach-Object -Process {
            $DL = $_
            $PageFile = $Vol = $null
            try {
                $Vol = Get-WmiObject -Class CIM_StorageVolume -Filter "Name='$($DL):\\'" -ErrorAction Stop
            } catch {
                Write-Warning -Message "Failed to find the DriveLetter $DL specified"
                return
            }
            if ($Vol.DriveType -ne 3) {
                Write-Warning -Message "The selected drive should be a fixed local volume"
                return
            }
            Switch ($PsCmdlet.ParameterSetName) {
                None {
                    try {
                        $PageFile = Get-WmiObject -Query "Select * From Win32_PageFileSetting Where Name='$($DL):\\pagefile.sys'" -ErrorAction Stop
                    } catch {
                        Write-Warning -Message "Failed to query the Win32_PageFileSetting class because $($_.Exception.Message)"
                    }
                    If($PageFile) {
                        try {
                            $PageFile | Remove-WmiObject -ErrorAction Stop 
                        } catch {
                            Write-Warning -Message "Failed to delete pagefile the Win32_PageFileSetting class because $($_.Exception.Message)"
                        }
                    } Else {
                        Write-Warning "$DL is already set None!"
                    }
                    break
                }
                SystemManagedSize {
                    Set-PageFileSize -DL $DL -InitialSize 0 -MaximumSize 0
                    break
                }
                Default {
                    if ($Vol.FreeSpace -gt $MaximumSize) {
                        Set-PageFileSize -DL $DL -InitialSize $InitialSize -MaximumSize $MaximumSize
                    } else {
                        Write-Warning -Message "Maximum size of page file being set exceeds the freespace available on the drive"
                    }
                }
            }
        }
 
        # Get current page file size information
        try {
            Get-WmiObject -Class Win32_PageFileSetting -ErrorAction Stop |Select-Object Name,
        @{Name="InitialSize(MB)";Expression={if($_.InitialSize -eq 0){"System Managed"}else{$_.InitialSize}}}, 
        @{Name="MaximumSize(MB)";Expression={if($_.MaximumSize -eq 0){"System Managed"}else{$_.MaximumSize}}}| 
        Format-Table -AutoSize
        } catch {
            Write-Warning -Message "Failed to query Win32_PageFileSetting class because $($_.Exception.Message)"
        }
        If($Reboot) {
            Restart-Computer -ComputerName $Env:COMPUTERNAME -Force
        }
    }
}
End {}
}
 
Function Set-PageFileSize {
[CmdletBinding()]
Param(
        [Parameter(Mandatory)]
        [Alias('dl')]
        [ValidatePattern('^[A-Z]$')]
        [String]$DriveLetter,
 
        [Parameter(Mandatory)]
        [ValidateRange(0,[int32]::MaxValue)]
        [Int32]$InitialSize,
 
        [Parameter(Mandatory)]
        [ValidateRange(0,[int32]::MaxValue)]
        [Int32]$MaximumSize
)
Begin {}
Process {
    #The AutomaticManagedPagefile property determines whether the system managed pagefile is enabled. 
    #This capability is not available on windows server 2003,XP and lower versions.
    #Only if it is NOT managed by the system and will also allow you to change these.
    try {
        $Sys = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop 
    } catch {
         
    }
 
    If($Sys.AutomaticManagedPagefile) {
        try {
            $Sys | Set-WmiObject -Property @{ AutomaticManagedPageFile = $false } -ErrorAction Stop
            Write-Verbose -Message "Set the AutomaticManagedPageFile to false"
        } catch {
            Write-Warning -Message "Failed to set the AutomaticManagedPageFile property to false in  Win32_ComputerSystem class because $($_.Exception.Message)"
        }
    }
     
    # Configuring the page file size
    try {
        $PageFile = Get-WmiObject -Class Win32_PageFileSetting -Filter "SettingID='pagefile.sys @ $($DriveLetter):'" -ErrorAction Stop
    } catch {
        Write-Warning -Message "Failed to query Win32_PageFileSetting class because $($_.Exception.Message)"
    }
 
    If($PageFile){
        try {
            $PageFile | Remove-WmiObject -ErrorAction Stop
        } catch {
            Write-Warning -Message "Failed to delete pagefile the Win32_PageFileSetting class because $($_.Exception.Message)"
        }
    }
    try {
        New-WmiObject -Class Win32_PageFileSetting -Property  @{Name= "$($DriveLetter):\pagefile.sys"} -ErrorAction Stop | Out-Null
      
        # http://msdn.microsoft.com/en-us/library/windows/desktop/aa394245%28v=vs.85%29.aspx            
        Get-WmiObject -Class Win32_PageFileSetting -Filter "SettingID='pagefile.sys @ $($DriveLetter):'" -ErrorAction Stop | Set-CimInstance -Property @{
            InitialSize = $InitialSize ;
            MaximumSize = $MaximumSize ; 
        } -ErrorAction Stop
         
        Write-Verbose -Message "Successfully configured the pagefile on drive letter $DriveLetter"
 
    } catch {
        Write-Warning "Pagefile configuration changed on computer '$Env:COMPUTERNAME'. The computer must be restarted for the changes to take effect."
    }
}
End {}
}
