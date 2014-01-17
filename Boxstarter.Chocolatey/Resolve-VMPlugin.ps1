function Resolve-VMPlugin {
    [CmdletBinding()]
    param(
        $Provider
    )

    DynamicParam {
        if(!$provider){$provider="HyperV"}
        $module=Get-Module "Boxstarter.$provider"
        $command = Get-Command $module\Enable-BoxstarterVM
        $metadata=New-Object System.Management.Automation.CommandMetaData($command)
        $paramDictionary = new-object `
                    -Type System.Management.Automation.RuntimeDefinedParameterDictionary

        $metadata.Parameters.Keys | % {
            $param=$metadata.Parameters[$_]
            $dynParam = new-object `
                    -Type System.Management.Automation.RuntimeDefinedParameter($param.Name, $param.ParameterType, $param.Attributes[1])
            $paramDictionary.Add($param.Name, $dynParam)
        }

        return $paramDictionary
    }
    Begin{
        $module=Get-Module "Boxstarter.$provider"
        $command = Get-Command $module\Enable-BoxstarterVM
        $PSBoundParameters.Remove("Provider") | Out-Null
        &($command) @PSBoundParameters
    }
}

new-alias Enable-BoxstarterVM Resolve-VMPlugin -force
