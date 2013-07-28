using System.Deployment.Application;
using System.Diagnostics;
using System.Reflection;
using System.Security.Principal;
using System.Web;

namespace Boxstarter.WebLaunch
{
    public class Launcher
    {
        public static void Main(string[] args)
        {
            var package = string.Empty;
            if (args.Length > 0)
            {
                package = args[0];
            }
            else if (ApplicationDeployment.IsNetworkDeployed && ApplicationDeployment.CurrentDeployment.ActivationUri != null)
            {
                var queryString = ApplicationDeployment.CurrentDeployment.ActivationUri.Query;
                package = HttpUtility.ParseQueryString(queryString)["package"];
            }

            var fileToRun = "boxstarter.bat";
            if (!IsRunAsAdministrator())
            {
                fileToRun = Assembly.GetExecutingAssembly().CodeBase;
            }

            var processInfo = new ProcessStartInfo(fileToRun)
            {
                Verb = "runas",
                Arguments = package
            };
            Process.Start(processInfo);
        }

        private static bool IsRunAsAdministrator()
        {
            var wi = WindowsIdentity.GetCurrent();
            var wp = new WindowsPrincipal(wi);

            return wp.IsInRole(WindowsBuiltInRole.Administrator);
        }
    }
}
