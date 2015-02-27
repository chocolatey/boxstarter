$chocoExe = "$env:ChocolateyInstall\choco.exe"
$chocoDll = "$($boxstarter.BaseDir)\\Boxstarter.Chocolatey\Chocolatey.dll"
if(Test-Path $chocoExe) {
    [Reflection.Assembly]::LoadFrom($chocoDll)
    Add-Type @"
    namespace Boxstarter
    {
        using System.Collections.Generic;
        using chocolatey;
        using chocolatey.infrastructure.adapters;
        using chocolatey.infrastructure.app.builders;
        using chocolatey.infrastructure.app.configuration;
        using chocolatey.infrastructure.app.services;
        using chocolatey.infrastructure.filesystem;
        using chocolatey.infrastructure.registration;

        public class ChocolateyWrapper
        {
            private readonly GetChocolatey _choco;

            public ChocolateyWrapper(string boxstarterPath) {
                _choco = Lets.GetChocolatey();
                _choco.RegisterContainerComponent<IPowershellService>(() => new PowershellService(new DotNetFileSystem(), new CustomString(string.Format("Import-Module {0}\\Boxstarter.Chocolatey\\Boxstarter.Chocolatey.psd1", boxstarterPath))));
                _choco.Set(conf => 
                {
                    //ConfigurationBuilder.set_up_configuration(new List<string>(args), conf, SimpleInjectorContainer.Container.GetInstance<IFileSystem>(), SimpleInjectorContainer.Container.GetInstance<IXmlService>(), null);
                    //ConfigurationOptions.parse_arguments_and_update_configuration(new List<string>(args), conf, null, null, null, null);
                    conf.AllowUnofficialBuild=true;
                });
            }

            public void Run(string[] args) {
                _choco.Run(args);
            }
        }
    }
"@ -ReferencedAssemblies $chocoDll
}
