function Invoke-RetriableScript{
<#
.SYNOPSIS
Retries a script 5 times or until it completes without terminating errors.
All Unnamed arguments will be passed as arguments to the script
#>
    param([ScriptBlock]$RetryScript)
    $currentErrorAction=$ErrorActionPreference
    try{
        $ErrorActionPreference = "Stop"
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
    finally{
        $ErrorActionPreference = $currentErrorAction
    }
}
