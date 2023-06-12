import jetbrains.buildServer.configs.kotlin.v2019_2.*
import jetbrains.buildServer.configs.kotlin.v2019_2.buildFeatures.pullRequests
import jetbrains.buildServer.configs.kotlin.v2019_2.buildSteps.nuGetPublish
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
        +:buildArtifacts/Boxstarter.*.nupkg
        +:buildArtifacts/Boxstarter.*.zip
        +:Web/Launch/**/* => webLaunch.zip
        -:Web/Launch/.gitattributes => webLaunch.zip
        +:BuildScripts/bootstrapper.ps1
    """.trimIndent()

    params {
        param("env.vcsroot.branch", "%vcsroot.branch%")
        param("env.Git_Branch", "%teamcity.build.vcs.branch.Boxstarter_BoxstarterVcsRoot%")
        param("teamcity.git.fetchAllHeads", "true")
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
            param("jetbrains_powershell_scriptArguments", "quick-deploy -buildCounter %build.counter%")
        }

        nuGetPublish {
            name = "Publish Packages"

            conditions {
                matches("teamcity.build.branch", "^(develop|release/.*|hotfix/.*|tags/.*)${'$'}")
            }

            toolPath = "%teamcity.tool.NuGet.CommandLine.DEFAULT%"
            packages = "buildArtifacts/*.nupkg"
            serverUrl = "%env.NUGETDEV_SOURCE%"
            apiKey = "%env.NUGETDEV_API_KEY%"
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
