---
name: New Boxstarter Release
about: Steps to be taken when doing a new Boxstarter Release
title: Boxstarter x.x.x Release
labels: ''
assignees: ''
---

> [!NOTE]
> This release process documents the process of deploying a new version of [Boxstarter](https://github.com/chocolatey/boxstarter).


- [ ] GitHub Milestone: <insert link here, once milestone has been created>
- [ ] GitHub Release: <insert link here, once release is complete>

## Pre-Release Checklist

- [ ] Ensure that a GitHub milestone has been created, and the issues that are going to be tackled in the milestone have been assigned to the milestone
  - [ ] Related to this, ensure that all issues have an appropriate title, that can then be used to generate the release notes
- [ ] Ask the question about whether a blog post is going to be required for this release or not

## Release Checklist

- [ ] All tagged releases of Boxstarter should come from:
  - [ ] The master branch for a normal release, or
  - [ ] A support/* branch if doing a backport/bugfix release for an earlier supported version, or
  - [ ] The hotfix/* or release/* branch, if a beta package is being released, or
  - [ ] The develop branch, if an alpha package is being released.
- [ ] Make sure that all issues in the upcoming milestone have exactly one of the [GitReleaseManager category labels](https://github.com/chocolatey/boxstarter/blob/develop/GitReleaseManager.yaml#L1-L9) associated with them or [one of the ignored labels](https://github.com/chocolatey/boxstarter/blob/develop/GitReleaseManager.yaml#L11-L13).
- [ ] If the GitHub milestone issues are still open, confirm that that are done before moving on. If they are in fact done, apply the `4 - Done` label and close the issue.
- [ ] Run the following command to generate release notes `.\GitReleaseManager.exe create -c <target-branch> -m <milestone> -n <milestone> --token <token> -o chocolatey -r boxstarter`
  - [ ] NOTE: Boxstarter build process does not include the installation of GitReleaseManager, so you will need to have it installed, either through Chocolatey or .NET Global Tools.
  - [ ] NOTE: If doing an alpha/beta release, don't run this step, instead generate the release notes manually.  GitReleaseManager uses labels and milestones to generate the release notes, and therefore won't understand what needs to be done, especially when there are multiple alpha/beta releases.
  - [ ] Ideally this should use the choco-bot GitHub account. There is a token for this in 1password
  - [ ] This will generate a new draft release on GitHub - the URL to the release should be output from the above command
  - [ ] If doing a release from a develop, support/*, release/*, or hotfix/* branch, verify that the target branch for creating the new tag is correctly set, and we are not tagging against master for this release.
- [ ] We need a blog post for the release (unless it has been decided to not do one - verify with someone in the Chocolatey Team) so wok with someone in the Chocolatey Team to draft one while you are doing the remainder of the release
- [ ] This step should only be done if this is NOT a beta release. Merge the hotfix or release branch into the target branch. This could be either master or support branch
  - [ ] `git checkout <target branch name>`
  - [ ] `git merge --no-ff <branch name>` i.e. hotfix/4.1.1 or release/4.2.0 whatever branch you are working on just now
- [ ] Push the changes to [upstream repository](https://github.com/chocolatey/boxstarter)
  - [ ] `git push upstream` - here upstream is assumed to be the above repository
  - [ ] `git push origin` - here origin is assumed to be your fork on the above repository
- [ ] Assuming everyone is happy, Publish the GitHub release
  - [ ] This will trigger a tagged build on the internal Chocolatey CI infrastructure.  Reach out to one of the Chocolatey Team to get the required packages Boxstarter, Boxstarter.Azure, Boxstarter.Bootstrapper, Boxstarter.Chocolatey, Boxstarter.Common, Boxstarter.HyperV, Boxstarter.TestRunner, and Boxstarter.WinConfig
- [ ] Push all the above nupkg's to the [Chocolatey Community Repository](https://community.chocolatey.org)
  - [ ] Use your own API Key
- [ ] Add all the nupkg's as well as the Boxstarter.<version_number>.zip file to the GitHub release
  - [ ] NOTE: This can be done using GitReleaseManager, something like the following, where it is assumed you have placed all the nupkg's into a single directory
    ```
    $assets = (ls "*") -join ','
    .\GitReleaseManager addasset -t 3.0.3 -o chocolatey -r boxstarter --token "<token_here>" -a "$assets"
    ```
- [ ] Move closed issues to  `5 - Released` at [https://github.com/chocolatey/boxstarter/issues?q=is%3Aissue+is%3Aclosed+label%3A%224+-+Done%22](https://github.com/chocolatey/boxstarter/issues?q=is%3Aissue+is%3Aclosed+label%3A%224+-+Done%22)
  - [ ] NOTE: This step should only be performed if this is a stable release. If an alpha/beta release, these issues won't be moved to released until the stable release is completed
- [ ] Use GitReleaseManager to close the milestone to that all associated issues are updated with a message saying that this has been released
  - [ ] NOTE: This step should only be performed if this is a stable release. While on an alpha/beta release we don't want to update the issues, since this will happen on the final stable release.
  - [ ] Use a command similar to the following `.\GitReleaseManager.exe close -m 0.17.0 --token <token_here> -o chocolatey -r boxstarter`
- [ ] Work with the Chocolatey Team to send out required release notifications
- [ ] Next up, we need to finalise the merging of changes back to the develop branch. Depending on what type of release you were performing, the steps are going to be different.
  - [ ] If this release comes from the master branch:
    - [ ] `git checkout develop`
    - [ ] `git merge --no-ff master`
    - [ ] There may be conflicts at this point, depending on if any changes have been made on the develop branch whilst the release was being done, these will need to be handled on a case by case basis.
  - [ ] If this release comes from a support/* branch, the following steps should be completed if changes made in this release need to be pulled into develop. This may not be necessary but check with folks before doing these steps
    - [ ] Create a new branch, for example merge-release-VERSION-changes from develop
      - [ ] `git switch develop`
      - [ ] `git switch -c merge-release-1.2.3-changes`
    - [ ] Cherry-pick relevant commits from the release into this new branch
      - [ ] `git cherry-pick COMMIT_HASH`
      - [ ] Repeat until all relevant commits are incorporated
      - [ ] If all commits since the last release on the support/* branch should be included, you can select these all at once with `git cherry-pick PREVIOUS_VERSION_TAG..support/*` (selecting the previous version tag and correct support/* base branch that the tag comes from)
    - [ ] Push this branch to your own fork of the repository and PR the changes into the develop branch on GitHub
- [ ] Delete the hotfix or release branch that was used during this process
  - [ ] NOTE: These steps should only be completed if there are no plans to do subsequent alpha/beta releases for this package version.
  - [ ] `git branch -d <hotfix or release branch name>`
  - [ ] If the hotfix or release branch was pushed to the upstream repository, delete it from there as well
- [ ] Push the changes to [upstream repository](https://github.com/chocolatey/boxstarter)
  - [ ] `git push upstream` - here upstream is assumed to be the above repository
  - [ ] `git push origin` - here origin is assumed to be your fork on the above repository
- [ ] Next we need to update the boxstarter.org website with the new version of Boxstarter
  - [ ] Create a branch for the changes that are away to be made
  - [ ] Edit the _Layout.cshtml to update the version number for download - there should be two places where this needs to be changed
  - [ ] Edit the index.cshtml to update the version number for download - there should be two places where this needs to be changed
  - [ ] Work with the Chocolatey Team to get the following artifacts from the tagged build
    - [ ] `bootstrapper.ps1` - place it into the input folder
    - [ ] `Boxstarter.<version_number>.zip` - place it into the input\downloads folder
    - [ ] `webLaunch.zipfile` - extract the contents into the input\launch folder.  This will replace the Boxstarter.WebLaunch.application and Boxstarter.WebLaunch.exe files, and create a new folder within the Application Files folder
  - [ ] Preview the website locally and verify that everything is working as expected, i.e. that the download links to the zip file are working as expected.  NOTE: It is not possible to test the ClickOnce installer locally.
  - [ ] Create a commit that contains all of these changes
  - [ ] Push the branch to your fork of boxstarter.org and create a PR for pulling these changes into the website
- [ ] Work with a member of the Chocolatey Team to update the information on the Boxstarter product page with anything that has been updated
- [ ] If a blog post was created for this release, update the GitHub Release and the Release Notes on the docs repository with a link to it
  - [ ] An example of this being done can be found
    - [ ] [GitHib Release](https://github.com/chocolatey/choco/releases/tag/2.3.0)
    - [ ] [Docs Site](https://docs.chocolatey.org/en-us/agent/release-notes/#v2.1.3)
  - [ ] Add a new highlight to the docs site for the release
    - [ ] [Example of a highlight being added](https://github.com/chocolatey/docs/commit/0912863d511fc59ecaab17910405a9387e6948d9)
    - [ ] [Instructions for adding a highlight](https://github.com/chocolatey/docs#adding-a-new-highlight)

## Post-Release Checklist

- [ ] Update the top of this issue with links to GitHub release and milestone.