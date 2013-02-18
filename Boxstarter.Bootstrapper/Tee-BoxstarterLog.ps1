function Tee-BoxstarterLog {
    param(
        [Parameter(position=0,Mandatory=$True,ValueFromPipeline=$True)]
        [object]$object
    )
    process {
        write-host $object
        $object >> $Boxstarter.Log
    }
}
