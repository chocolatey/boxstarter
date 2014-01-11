$source = @"
public class BoxstarterConnectionConfig {
    public BoxstarterConnectionConfig(System.Uri connectionURI, System.Management.Automation.PSCredential credential) {
        ConnectionURI=connectionURI;
        Credential=credential;
    }
    public System.Uri ConnectionURI;
    public System.Management.Automation.PSCredential Credential;
}
"@
Add-Type -TypeDefinition $source