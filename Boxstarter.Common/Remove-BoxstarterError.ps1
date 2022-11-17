function Remove-BoxstarterError {
<#
.SYNOPSIS
Removes errors from the error collection that occur within a block.

#>
    param([ScriptBlock]$block)

    $currentErrorAction=$Global:ErrorActionPreference
    $currentErrorCount = $Global:Error.Count

    try{
        $Global:ErrorActionPreference = "SilentlyContinue"
        Invoke-Command -ScriptBlock $block

        while($Global:Error.Count -gt $currentErrorCount){
            $Global:Error.RemoveAt(0)
        }
    }
    finally{
        $Global:ErrorActionPreference = $currentErrorAction
    }
}
