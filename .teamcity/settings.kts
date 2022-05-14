import jetbrains.buildServer.configs.kotlin.v2019_2.*
import jetbrains.buildServer.configs.kotlin.v2019_2.buildFeatures.pullRequests
import jetbrains.buildServer.configs.kotlin.v2019_2.buildSteps.powerShell
import jetbrains.buildServer.configs.kotlin.v2019_2.triggers.vcs
import jetbrains.buildServer.configs.kotlin.v2019_2.vcs.GitVcsRoot

version = "2021.2"

project {
    buildType(Build)
}

object Build : BuildType({
    name = "Build"

    artifactRules = """
        buildArtifacts => buildArtifacts
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

            conditions {
                equals("teamcity.build.branch.is_default", "true")
            }
        }
        powerShell {
            name = "Build"
            scriptMode = file {
                path = "BuildScripts/build.ps1"
            }
            param("jetbrains_powershell_scriptArguments", "quick-deploy")
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
