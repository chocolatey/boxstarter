function Resolve-VMPlugin {
    [CmdletBinding()]
    [OutputType([BoxstarterConnectionConfig])]
    param(
        $Provider
    )

    DynamicParam {
        if($provider -eq $null -or $Provider.Length -eq 0){$provider="HyperV"}
        $unNormalized=(Get-Item "$PSScriptRoot\..\Boxstarter.$provider\Boxstarter.$provider.psd1")
        Import-Module $unNormalized.FullName -global -DisableNameChecking -Force -ErrorAction SilentlyContinue | Out-Null
        $module=Get-Module "Boxstarter.$provider"
        if($module) {
            $command = Get-Command "$module\Enable-BoxstarterVM"
            $metadata=New-Object System.Management.Automation.CommandMetaData($command)
            $paramDictionary = new-object `
                        -Type System.Management.Automation.RuntimeDefinedParameterDictionary

            $metadata.Parameters.Keys | % {
                $param=$metadata.Parameters[$_]
                $attr = $param.Attributes | ? { $_.TypeId -eq [System.Management.Automation.ParameterAttribute] }
                $dynParam = new-object `
                        -Type System.Management.Automation.RuntimeDefinedParameter($param.Name, $param.ParameterType, $attr)
                $paramDictionary.Add($param.Name, $dynParam)
            }

            return $paramDictionary
        }
    }
    Process{
        if($provider -eq $null -or $Provider.Length -eq 0){$provider="HyperV"}
        $module=Get-Module "Boxstarter.$provider"
        if($module) {
            $command = Get-Command "$module\Enable-BoxstarterVM"
            $PSBoundParameters.Remove("Provider") | Out-Null
            &($command) @PSBoundParameters
        }
    }
}

new-alias Enable-BoxstarterVM Resolve-VMPlugin -force
