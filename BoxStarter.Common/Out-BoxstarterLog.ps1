function Enter-BoxstarterLogable ([ScriptBlock] $script){
    & ($script) 2>&1 | Out-BoxstarterLog
}

function Out-BoxstarterLog {
    param(
        [Parameter(position=0,Mandatory=$True,ValueFromPipeline=$True)]
        [object]$object
    )
    process {
        write-host $object
        if($Boxstarter -and $BoxStarter.Log){
            $object >> $Boxstarter.Log            
        }
    }
}
