function Invoke-PSWMIMethod($ComputerName, $Credential, $Command){
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))
    Invoke-WmiMethod -Computer $ComputerName -Credential $Credential Win32_Process Create -Args "powershell -NoProfile -EncodedCommand $encoded"
}