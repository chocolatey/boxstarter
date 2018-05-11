$source = @"
public class BoxstarterConnectionConfig {
    public BoxstarterConnectionConfig(System.Uri connectionURI, System.Management.Automation.PSCredential credential, System.Management.Automation.Remoting.PSSessionOption psSessionOption) {
        ConnectionURI=connectionURI;
        Credential=credential;
        PSSessionOption=psSessionOption;
    }
    public System.Uri ConnectionURI;
    public System.Management.Automation.PSCredential Credential;
    public System.Management.Automation.Remoting.PSSessionOption PSSessionOption;
}
"@
Add-Type -TypeDefinition $source
