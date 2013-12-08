$source = @"
public class BoxstarterConnectionConfig {
    public BoxstarterConnectionConfig(string computerName, System.Management.Automation.PSCredential credential) {
        ComputerName=computerName;
        Credential=credential;
    }
    public string ComputerName { get; set; }
    public System.Management.Automation.PSCredential Credential { get; set; }
}
"@
Add-Type -TypeDefinition $source