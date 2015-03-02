using System.Collections;
using System.Management.Automation.Host;
using chocolatey;
using chocolatey.infrastructure.app.services;
using chocolatey.infrastructure.filesystem;

namespace boxstarter.choco
{
    public class ChocolateyWrapper
    {
        private readonly GetChocolatey _choco;
        private readonly string _boxstarterPath;
        private readonly PowershellRunspaceService _psService;

        public ChocolateyWrapper(string boxstarterPath, PSHost host)
        {
            _psService = new PowershellRunspaceService(new DotNetFileSystem(), host);
            _boxstarterPath = boxstarterPath;
            _choco = Lets.GetChocolatey();
            _choco.RegisterContainerComponent<IPowershellService>(() => _psService);
            _choco.Set(conf =>
            {
                conf.AllowUnofficialBuild = true;
            });
        }

        public void Run(string[] args, Hashtable boxstarter)
        {
            _psService.Set(rs =>
            {
                rs.InitialSessionState.ImportPSModule(new[] { string.Format("{0}\\Boxstarter.Chocolatey\\Boxstarter.Chocolatey.psd1", _boxstarterPath) });
                rs.SessionStateProxy.SetVariable("Boxstarter", boxstarter);
            });
            _choco.RunConsole(args);
        }
    }
}
