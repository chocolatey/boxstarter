function Create-BoxstarterTask ($Credential){
    if($BoxstarterPassword.length -gt 0){
        schtasks /CREATE /TN 'Boxstarter Task' /SC WEEKLY /RL HIGHEST `
            /RU "$($Credential.UserName)"  /IT /RP $Credential.GetNetworkCredential().Password `
        /TR "powershell -noprofile -ExecutionPolicy Bypass -File $env:temp\BoxstarterTask.ps1" /F |
            Out-Null
    }
    else { #For testing
        schtasks /CREATE /TN 'Boxstarter Task' /SC WEEKLY /RL HIGHEST `
                /RU "$($Credential.UserName)" /IT `
        /TR "powershell -noprofile -ExecutionPolicy Bypass -File $env:temp\BoxstarterTask.ps1" /F |
                Out-Null
    }
    if($LastExitCode -gt 0){
        throw "Unable to create scheduled task as $($Credential.UserName)"
    }
}