function Invoke-RetriableScript{
<#
.SYNOPSIS
Retries a script 5 times or until it completes without terminating errors. 
All Unnamed ars will be passed as arguments to the script
#>
    param([ScriptBlock]$RetryScript)
    for($count = 1; $count -le 5; $count++) {
        try {
            Write-BoxstarterMessage "Attempt #$count..." -Verbose
            $ret = Invoke-Command -ScriptBlock $RetryScript -ArgumentList $args
            return $ret
            break
        }
        catch {
            if($global:Error.Count -gt 0){$global:Error.RemoveAt(0)}
            if($count -eq 5) { throw $_ }
            else { Sleep 10 }
        }
    }
}