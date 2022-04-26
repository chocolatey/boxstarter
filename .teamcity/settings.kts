import jetbrains.buildServer.configs.kotlin.v2019_2.*
import jetbrains.buildServer.configs.kotlin.v2019_2.buildFeatures.pullRequests
import jetbrains.buildServer.configs.kotlin.v2019_2.buildSteps.powerShell
import jetbrains.buildServer.configs.kotlin.v2019_2.triggers.vcs
import jetbrains.buildServer.configs.kotlin.v2019_2.vcs.GitVcsRoot

version = "2021.2"

project {
    buildType(Boxstarter)
}

object Boxstarter : BuildType({
    id = AbsoluteId("Boxstarter")
    name = "Build"

    artifactRules = """
        buildArtifacts => buildArtifacts
        web => web-%system.build.number%.zip
    """.trimIndent()

    params {
        param("env.CERT_SUBJECT_NAME", "Chocolatey Software, Inc.")
    }

    vcs {
        root(DslContext.settingsRoot)

        branchFilter = """
            +:*
        """.trimIndent()
    }

    steps {
        powerShell {
            name = "Prerequisites"
            scriptMode = script {
                content = """
                    if ((Get-WindowsFeature -Name NET-Framework-Core).InstallState -ne 'Installed') {
                        Install-WindowsFeature -Name NET-Framework-Core
                    }
                """.trimIndent()
            }
        }
        step {
            name = "Include Signing Keys"
            type = "PrepareSigningEnvironment"
        }
        powerShell {
            name = "Build"
            scriptMode = file {
                path = "BuildScripts/build.ps1"
            }
            param("jetbrains_powershell_scriptArguments", "quick-deploy -buildCounter %build.counter%"")
        }
    }

    triggers {
        vcs {
            branchFilter = ""
        }
    }

    features {
        pullRequests {
            provider = github {
                authType = token {
                    token = "%system.GitHubPAT%"
                }
            }
        }
    }
})
