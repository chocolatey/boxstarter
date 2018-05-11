function Restart-Explorer {

    try{
        Write-BoxstarterMessage "Restarting the Windows Explorer process..."
        $user = Get-CurrentUser
        try { $explorer = Get-Process -Name explorer -ErrorAction stop -IncludeUserName }
        catch {$global:error.RemoveAt(0)}

        if($explorer -ne $null) {
            $explorer | ? { $_.UserName -eq "$($user.Domain)\$($user.Name)"} | Stop-Process -Force -ErrorAction Stop | Out-Null
        }

        Start-Sleep 1

        if(!(Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
            $global:error.RemoveAt(0)
            start-Process -FilePath explorer
        }
    } catch {$global:error.RemoveAt(0)}
}
