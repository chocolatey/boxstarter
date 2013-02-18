function Start-UpdateServices {
    Write-BoxstarterMessage "Starting Windows Update Service"
    Start-Service -Name wuauserv
    Start-CCMEXEC
}

function Start-CCMEXEC {
    $ccm = get-service -include CCMEXEC
    if($ccm) {
        Write-BoxstarterMessage "Starting Configuration Manager Service"
        set-service CCMEXEC -startuptype automatic
        Start-Service CCMEXEC
    }
}