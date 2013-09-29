function Invoke-PSWMIMethod($ComputerName, $Command){
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))
    Invoke-WmiMethod -Computer $ComputerName Win32_Process Create -Args "powershell -NoProfile -EncodedCommand $encoded"
}