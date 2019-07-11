Function Set-BoxstarterPageFile {
<#
    .SYNOPSIS
        This can be used to manage the Windows page file.
    .DESCRIPTION
        This can be used to manage the Windows page file.
    .PARAMETER InitialSizeMB
        Initial size of the page file.
    .PARAMETER MaximumSizeMB
        Maximum size of the page file.
    .PARAMETER DriveLetter
        The drive used for the holding the page file.
    .PARAMETER SystemManagedSize
        Allow Windows to manage the page files.
    .PARAMETER Disable
        Disable the use of the page file.
    .EXAMPLE
        C:\PS> Set-PageFile -InitialSizeMB 1024 -MaximumSizeMB 4096 -DriveLetter "C","D"

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
        [Int32]$InitialSizeMB,

        [Parameter(Mandatory,ParameterSetName="SetPageFileSize")]
        [Alias('ms')]
        [Int32]$MaximumSizeMB,

        [Parameter(Mandatory)]
        [Alias('dl')]
        [ValidatePattern('^[A-Z]$')]
        [String[]]$DriveLetter,

        [Parameter(Mandatory,ParameterSetName="Disable")]
        [Switch]$Disable,

        [Parameter(Mandatory,ParameterSetName="SystemManagedSize")]
        [Switch]$SystemManagedSize
    )

    Function Set-PageFileSize {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory)]
            [ValidatePattern('^[A-Z]$')]
            [String]$DriveLetter,

            [Parameter(Mandatory)]
            [ValidateRange(0, [int32]::MaxValue)]
            [Int32]$InitialSizeMB,

            [Parameter(Mandatory)]
            [ValidateRange(0, [int32]::MaxValue)]
            [Int32]$MaximumSizeMB
        )
        # There is a bug in earlier versions of PowerShell when using put() in
        # that it would throw an exception but actually make the change. The
        # EnableAllPrivileges switch for Get-WmiObject seems to stop this
        # exception being thrown.
        $pfStatus = Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges -ErrorAction Stop
        if ($pfStatus.AutomaticManagedPagefile -eq $true) {
            # disable automatic management of the pagefile
            $pfStatus.AutomaticManagedPagefile = $false

            # we use put() to keep comatibility with PowerShell 2
            $null = $pfStatus.Put()

            # when we disable the AutomaticManagedPagefile it starts to use the
            # $env:SystemDrive for the page file so lets remove that
            Get-WmiObject -Class Win32_PageFileSetting -Filter "SettingID='pagefile.sys @ $($env:SystemDrive)'" -ErrorAction Stop | Remove-WmiObject -ErrorAction Stop
        }

        # if the pagefile exists on $DriveLetter then remove it
        Get-WmiObject -Class Win32_PageFileSetting -Filter "SettingID='pagefile.sys @ $($DriveLetter):'" -EnableAllPrivileges -ErrorAction Stop | Remove-WmiObject -ErrorAction Stop

        # create a new instance of a the Wwin32_PageFileSetting object
        $newPf = (New-Object -TypeName System.Management.ManagementClass('root\cimv2', 'Win32_PageFileSetting', $null)).CreateInstance()

        # we appear to have do do this in bits rather than all at once
        # See https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-pagefilesetting
        # set the name first which is simply the path of the pagefile
        $newPf.Name = "$($DriveLetter):\pagefile.sys"
        $null = $newPf.Put()

        # now we need to set teh initial and maximum pagefile sizes
        $newPf.InitialSize = $InitialSizeMB
        $newPf.MaximumSize = $MaximumSizeMB
        $null = $newPf.Put()
    } #function

    # check that maximum is above or equal minimum before we start
    if ($MaximumSizeMB -lt $InitialSizeMB) {
        Write-BoxstarterMessage "You have set the maximum pagefile size to be lower than the minimum. Exiting." -color red
        return
    }

    ForEach ($dl in $DriveLetter) {
        # adding DriveType to the WMI Filter doesn't appear to work :(
        $vol = Get-WmiObject -Class CIM_StorageVolume -Filter "Name='$($dl):\\'" -ErrorAction Stop | Where-Object { $_.DriveType -eq 3 }
        if ($null -eq $vol) {
            Write-BoxstarterMessage "Could not find volume '$($dl):'. Either it does not exist or it is not a fixed local volume." -color red
            return
        }

        Switch ($PsCmdlet.ParameterSetName) {
            Disable {
                try {
                    Get-WmiObject -Class Win32_PageFileSetting -Filter "Name='$($dl):\\pagefile.sys'" -ErrorAction Stop | Remove-WmiObject -ErrorAction Stop
                }
                catch {
                    Write-BoxStarterMessage "Unable to disable the pagefile on '$($dl):'. (Error: $($_.Exception.Message))"
                    return
                }
            }

            SystemManagedSize {
                try {
                    Set-PageFileSize -DriveLetter $dl -InitialSizeMB 0 -MaximumSizeMB 0
                }
                catch {
                    Write-BoxstarterMessage "Unable to set the pagefile size to be managed by the System. (Error: $($_.Exception.Message))"
                    return
                }
                break
            }

            Default {
                # $vol stores it's freespace in bytes but we need to compare MB
                $freespace = $vol.FreeSpace / 1MB
                if ($freespace -gt $MaximumSizeMB) {
                    try {
                        Set-PageFileSize -DriveLetter $dl -InitialSizeMB $InitialSizeMB -MaximumSizeMB $MaximumSizeMB
                    }
                    catch {
                        $msg = "Failed to set pagefile on '{0}:' to {1}MB / {2}MB. (Error: $($_.Exception.Message))." -f $dl, $InitialSizeMB, $MaximumSizeMB
                        Write-BoxstarterMessage $msg -color red
                    }
                }
                else {
                    $msg = "Failed to set pagefile on '{0}:' to {1}MB / {2}MB. The maximum pagefile size exceeds the free space on the volume." -f $dl, $InitialSizeMB, $MaximumSizeMB
                    Write-BoxstarterMessage $msg -color red
                    return
                }
            } #switch - default
        } #switch
    } #foreach

    Write-BoxstarterMessage "A reboot is required before the pagefile changes will take effect."
    Get-WmiObject -Class Win32_PageFileSetting -ErrorAction Stop |Select-Object Name,
        @{Name = "InitialSize(MB)"; Expression={ if ($_.InitialSizeMB -eq 0) { "System Managed" } else { $_.InitialSizeMB }}},
        @{Name = "MaximumSize(MB)"; Expression={ if ($_.MaximumSizeMB -eq 0) { "System Managed" } else { $_.MaximumSizeMB }}} |
        Format-Table -AutoSize
}
