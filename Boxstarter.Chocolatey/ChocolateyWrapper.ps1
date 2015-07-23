Add-Type @"
namespace Boxstarter
{
    using chocolatey;
    using chocolatey.infrastructure.app.services;
    using chocolatey.infrastructure.filesystem;

    public class ChocolateyWrapper
    {
        private GetChocolatey _choco;
        
        public ChocolateyWrapper(string boxstarterSetup) {
            _choco = Lets.GetChocolatey();
            var psService = new PowershellService(new DotNetFileSystem(), boxstarterSetup);
            _choco.RegisterContainerComponent<IPowershellService>(() => psService);
        }

        public void Run(string[] args) {
            _choco.RunConsole(args);
        }
    }
}
"@ -ReferencedAssemblies @( "$($Boxstarter.BaseDir)/boxstarter.chocolatey/chocolatey/chocolatey.dll" )
