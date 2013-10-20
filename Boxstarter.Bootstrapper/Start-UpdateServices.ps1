function Start-UpdateServices {
    $wuaStatus = (Get-Service wuauserv).Status
    if($wuaStatus -ne "Running"){
        Write-BoxstarterMessage "Starting Windows Update Service"
        Enter-BoxstarterLogable {
            Set-Service -Name wuauserv -StartupType Automatic
            Start-Service -Name wuauserv -ErrorAction SilentlyContinue 
        }
    }
    Start-CCMEXEC
}

function Start-CCMEXEC {
    $ccm = get-service -include CCMEXEC
    if($ccm -and $ccm.Status -ne "Running") {
        Write-BoxstarterMessage "Starting Configuration Manager Service"
        set-service CCMEXEC -startuptype automatic
        Enter-BoxstarterLogable { Start-Service CCMEXEC -ErrorAction SilentlyContinue }
    }
}