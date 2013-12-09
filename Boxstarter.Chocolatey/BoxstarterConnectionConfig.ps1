$source = @"
public class BoxstarterConnectionConfig {
    public BoxstarterConnectionConfig(string computerName, System.Management.Automation.PSCredential credential) {
        ComputerName=computerName;
        Credential=credential;
    }
    public string ComputerName;
    public System.Management.Automation.PSCredential Credential;
}
"@
Add-Type -TypeDefinition $source