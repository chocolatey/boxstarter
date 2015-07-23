Add-Type @"
namespace Boxstarter
{
    using chocolatey;
    using chocolatey.infrastructure.app.services;
    using chocolatey.infrastructure.filesystem;

    public class ChocolateyWrapper
    {
        public void Run(string[] args, string boxstarterSetup) {
            var choco = Lets.GetChocolatey();
            var psService = new PowershellService(new DotNetFileSystem(), boxstarterSetup);
            choco.RegisterContainerComponent<IPowershellService>(() => psService);
            choco.RunConsole(args);
        }
    }
}
"@ -ReferencedAssemblies @( "$($Boxstarter.BaseDir)/boxstarter.chocolatey/chocolatey/chocolatey.dll" )
