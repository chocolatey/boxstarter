function Resolve-VMPlugin {
    [CmdletBinding()]
    [OutputType([BoxstarterConnectionConfig])]
    param(
        $Provider
    )

    DynamicParam {
        if($provider -eq $null -or $Provider.Length -eq 0){$provider="HyperV"}
        Import-Module "Boxstarter.$provider" -ErrorAction SilentlyContinue | Out-Null
        $module=Get-Module "Boxstarter.$provider"
        $command = Get-Command "$module\Enable-BoxstarterVM"
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
    Process{
        if($provider -eq $null -or $Provider.Length -eq 0){$provider="HyperV"}
        $module=Get-Module "Boxstarter.$provider"
        $command = Get-Command "$module\Enable-BoxstarterVM"
        $PSBoundParameters.Remove("Provider") | Out-Null
        &($command) @PSBoundParameters
    }
}

new-alias Enable-BoxstarterVM Resolve-VMPlugin -force
