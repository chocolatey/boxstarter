# $chocoExe = "$env:ChocolateyInstall\choco.exe"
# $chocoDll = "$($boxstarter.BaseDir)\\Boxstarter.Chocolatey\Chocolatey.dll"
# $automation = "$($boxstarter.BaseDir)\\Boxstarter.Chocolatey\System.Management.Automation.dll"
# if(Test-Path $chocoExe) {
#     [Reflection.Assembly]::LoadFrom($chocoDll)
#     Add-Type @"
#     namespace Boxstarter
#     {
#         using System.Collections.Generic;
#         using chocolatey;
#         using chocolatey.infrastructure.adapters;
#         using chocolatey.infrastructure.app.builders;
#         using chocolatey.infrastructure.app.configuration;
#         using chocolatey.infrastructure.app.services;
#         using chocolatey.infrastructure.filesystem;
#         using chocolatey.infrastructure.registration;
#         using System.Collections;
#         using System.Management.Automation.Host;

#         public class ChocolateyWrapper
#         {
#             private readonly GetChocolatey _choco;
#             private readonly string _boxstarterPath;
#             private readonly PowershellRunspaceService _psService;

#             public ChocolateyWrapper(string boxstarterPath, PSHost host) {
#                 _psService = new PowershellRunspaceService(new DotNetFileSystem(), host);
#                 _boxstarterPath = boxstarterPath;
#                 _choco = Lets.GetChocolatey();
#                 _choco.RegisterContainerComponent<IPowershellService>(() => _psService);
#                 _choco.Set(conf => 
#                 {
#                     conf.AllowUnofficialBuild=true;
#                 });
#             }

#             public void Run(string[] args, Hashtable boxstarter) {
#                 _psService.Set(rs => {
#                     rs.InitialSessionState.ImportPSModule(new[] { string.Format("{0}\\Boxstarter.Chocolatey\\Boxstarter.Chocolatey.psd1", _boxstarterPath) });
#                     rs.SessionStateProxy.SetVariable("Boxstarter", boxstarter);
#                 });
#                 _choco.RunConsole(args);
#             }
#         }
#     }
# "@ -ReferencedAssemblies @($automation,$chocoDll)
# }

Add-Type -path "C:\dev\boxstarter\boxstarter.choco\bin\Debug\boxstarter.choco.dll"