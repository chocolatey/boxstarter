# Contributing
The Chocolatey team has very explicit information here regarding the process for contributions, and we will be sticklers about the way you write your commit messages (yes, really), so to save yourself some rework, please make sure you read over this entire document prior to contributing.

<!-- TOC -->

- [Reporting an Issue/Bug?](#reporting-an-issuebug)
- [Submitting an Enhancement / Feature Request?](#submitting-an-enhancement)
    - [Submitting an Enhancement For Choco](#submitting-an-enhancement)
- [Contributing](#contributing)
  - [Prerequisites](#prerequisites)
    - [Definition of Trivial Contributions](#definition-of-trivial-contributions)
    - [Is the CLA Really Required?](#is-the-cla-really-required)
- [Contributing Process](#contributing-process)
  - [Get Buyoff Or Find Open Community Issues/Features](#get-buyoff-or-find-open-community-issuesfeatures)
  - [Set Up Your Environment](#set-up-your-environment)
  - [Code Format / Design](#code-format--design)
    - [CSharp](#csharp)
    - [PowerShell](#powershell)
  - [Debugging / Testing](#debugging--testing)
    - [Visual Studio](#visual-studio)
      - [Automated Tests](#automated-tests)
    - [Chocolatey Build](#chocolatey-build)
  - [Prepare Commits](#prepare-commits)
  - [Submit Pull Request (PR)](#submit-pull-request-pr)
  - [Respond to Feedback on Pull Request](#respond-to-feedback-on-pull-request)
- [Other General Information](#other-general-information)

<!-- /TOC -->

## Reporting an Issue/Bug?

Submitting an Issue (or a Bug)? See the [Submitting Issues](https://github.com/chocolatey/boxstarter#submitting-issues) section in the [README](https://github.com/chocolatey/boxstarter/blob/master/README.md#submitting-issues).

## Submitting an Enhancement
Log a GitHub issue. There are less constraints on this versus reporting issues. The process for contributions is roughly as follows:

### Prerequisites
 * Submit the Enhancement ticket. You will need the issue id for your commits.
 * You agree to follow the [etiquette regarding communication](https://github.com/chocolatey/boxstarter#etiquette-regarding-communication).

#### Definition of Trivial Contributions
It's hard to define what is a trivial contribution. Sometimes even a 1 character change can be considered significant. Unfortunately because it can be subjective, the decision on what is trivial comes from the committers of the project and not from folks contributing to the project.

What is generally considered trivial:

* Fixing a typo
* Documentation changes
* Fixes to non-production code - like fixing something small in the build code.

What is generally not considered trivial:

 * Changes to any code that would be delivered as part of the final product. This includes any scripts that are delivered, such as PowerShell scripts. Yes, even 1 character changes could be considered non-trivial.

## Contributing Process

Start with [Prerequisites](#prerequisites).

### Get Buyoff Or Find Open Community Issues/Features
 * Through a Github issue (preferred), through the [mailing list](https://groups.google.com/forum/#!forum/boxstarter), or through [Gitter](https://gitter.im/chocolatey/boxstarter), talk about a feature you would like to see (or a bug fix), and why it should be in Boxstarter.
   * If approved through the mailing list or in [Gitter chat](https://gitter.im/chocolatey/boxstarter), ensure the accompanying GitHub issue is created with information and a link back to the mailing list discussion (or the Gitter conversation).
 * Once you get a nod from one of the [Chocolatey Team](https://github.com/chocolatey?tab=members), you can start on the feature.
 * Alternatively, if a feature is on the issues list with the [Up For Grabs](https://github.com/chocolatey/boxstarter/issues?q=is%3Aopen+is%3Aissue+label%3A%22Up+For+Grabs%22) label, it is open for a community member (contributor) to patch. You should comment that you are signing up for it on the issue so someone else doesn't also sign up for the work.

### Set Up Your Environment
 * Visual Studio 2010+ is recommended for code contributions.
 * For git specific information:
    1. Create a fork of chocolatey/boxstarter under your GitHub account. See [forks](https://help.github.com/articles/working-with-forks/) for more information.
    1. [Clone your fork](https://help.github.com/articles/cloning-a-repository/) locally.
    1. Open a command line and navigate to that directory.
    1. Add the upstream fork - `git remote add upstream git@github.com:chocolatey/boxstarter.git`
    1. Run `git fetch upstream`
    1. Ensure you have user name and email set appropriately to attribute your contributions - see [Name](https://help.github.com/articles/setting-your-username-in-git/) / [Email](https://help.github.com/articles/setting-your-commit-email-address-in-git/).
    1. Ensure that the local repository has the following settings (without `--global`, these only apply to the *current* repository):
      * `git config core.autocrlf false`
      * `git config core.symlinks false`
      * `git config merge.ff false`
      * `git config merge.log true`
      * `git config fetch.prune true`
    1. From there you create a branch named specific to the feature.
    1. In the branch you do work specific to the feature.
    1. For committing the code, please see [Prepare Commits](#prepare-commits).
    1. See [Submit Pull Request (PR)](#submit-pull-request-pr).
 * Please also observe the following:
    * Unless specifically requested, do not reformat the code. It makes it very difficult to see the change you've made.
    * Do not change files that are not specific to the feature.
    * More covered below in the [**Prepare commits**](#prepare-commits) section.
 * Test your changes and please help us out by updating and implementing some automated tests. It is recommended that all contributors spend some time looking over the tests in the source code. You can't go wrong emulating one of the existing tests and then changing it specific to the behavior you are testing.
    * While not an absolute requirement, automated tests will help reviewers feel comfortable about your changes, which gets your contributions accepted faster.
 * Please do not update your branch from the master unless we ask you to. See the responding to feedback section below.

### Code Format / Design
#### CSharp
 * If you are using ReSharper, all of this is already in the shared resharper settings.
 * Class names and Properties are `PascalCase` - this is nearly the only time you start with uppercase.
 * Namespaces (and their representative folders) are lowercase.
 * Methods and functions are lowercase. Breaks between words in functions are typically met with an underscore (`_`, e.g. `run_actual()`).
 * Variables and parameters are `camelCase`.
 * Constants are `UPPER_CASE`.
 * There are some adapters over the .NET Framework to ensure some additional functionality works and is consistent. Sometimes this is completely seamless that you are using these (e.g. `Console`).

#### PowerShell
 * PowerShell must be CRLF and UTF-8. Git attributes are not used, so Git will not ensure this for you.
 * The minimum version of PowerShell this must work with is v2. This makes things somewhat more limited but compatible across the board for all areas Boxstarter is deployed. It is getting harder to find a reference for PowerShell v2, but this is a good one: http://adamringenberg.com/powershell2/table-of-contents/.
 * If you add a new file, also ensure you add it to the Visual Studio project and ensure it becomes an embedded resource.
 * The last parameter in every function must be `[parameter(ValueFromRemainingArguments = $true)][Object[]] $ignoredArguments`. This allows for future expansion and compatibility - as new parameters are introduced and used, it doesn't break older versions of Boxstarter.
 * Do not add new positional elements to functions. We want to promote using named parameters in calling functions.
 * Do not remove any existing positional elements from functions. We need to maintain compatibility with older versions of Boxstarter.

### Prepare Commits
This section serves to help you understand what makes a good commit.

A commit should observe the following:

 * A commit is a small logical unit that represents a change.
 * Should include new or changed tests relevant to the changes you are making.
 * No unnecessary whitespace. Check for whitespace with `git diff --check` and `git diff --cached --check` before commit.
 * You can stage parts of a file for commit.

A commit message should observe the following (based on ["A Note About Git Commit Messages"](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html)):

  * The first line of the commit message should be a short description around 50 characters in length and be prefixed with the GitHub issue it refers to with parentheses surrounding that. If the GitHub issue is #25, you should have `(GH-25)` prefixed to the message.
  * If the commit is about documentation, the message should be prefixed with `(doc)`.
  * If it is a trivial commit or one of formatting/spaces fixes, it should be prefixed with `(maint)`.
  * After the subject, skip one line and fill out a body if the subject line is not informative enough.
  * Sometimes you will find that even a tiny code change has a commit body that needs to be very detailed and make take more time to do than the actual change itself!
  * The body:
    * Should wrap at `72` characters.
    * Explains more fully the reason(s) for the change and contrasts with previous behavior.
    * Uses present tense. "Fix" versus "Fixed".

A good example of a commit message is as follows:

```
(GH-7) Installation Adds All Required Folders

Previously the installation script worked for the older version of
Boxstarter. It does not work similarly for the newer versions due
to location changes for the newer folders. Update the install
script to ensure all folder paths exist.

Without this change the install script will not fully install the new
Boxstarter properly.
```

### Submit Pull Request (PR)
Prerequisites:

 * You are making commits in a feature branch.
 * All specs should be passing.

Submitting PR:

 * Once you feel it is ready, submit the pull request to the `chocolatey/boxstarter` repository against the `master` branch ([more information on this can be found here](https://help.github.com/articles/creating-a-pull-request)) unless specifically requested to submit it against another branch.
  * In the case of a larger change that is going to require more discussion, please submit a PR sooner. Waiting until you are ready may mean more changes than you are interested in if the changes are taking things in a direction the committers do not want to go.
 * In the pull request, outline what you did and point to specific conversations (as in URLs) and issues that you are are resolving. This is a tremendous help for us in evaluation and acceptance.
 * Once the pull request is in, please do not delete the branch or close the pull request (unless something is wrong with it).
 * One of the Chocolatey Team members, or one of the committers, will evaluate it within a reasonable time period (which is to say usually within 2-4 weeks). Some things get evaluated faster or fast tracked. We are human and we have active lives outside of open source so don't fret if you haven't seen any activity on your pull request within a month or two. We don't have a Service Level Agreement (SLA) for pull requests. Just know that we will evaluate your pull request.

### Respond to Feedback on Pull Request
We may have feedback for you in the form of requested changes or fixes. We generally like to see that pushed against the same topic branch (it will automatically update the PR). You can also fix/squash/rebase commits and push the same topic branch with `--force` (while it is generally acceptable to do this on topic branches not in the main repository, a force push should be avoided at all costs against the main repository).

If we have comments or questions when we do evaluate it and receive no response, it will probably lessen the chance of getting accepted. Eventually this means it will be closed if it is not accepted. Please know this doesn't mean we don't value your contribution, just that things go stale. If in the future you want to pick it back up, feel free to address our concerns/questions/feedback and reopen the issue/open a new PR (referencing old one).

Sometimes we may need you to rebase your commit against the latest code before we can review it further. If this happens, you can do the following:

 * `git fetch upstream` (upstream would be the mainstream repo or `chocolatey/boxstarter` in this case)
 * `git checkout master`
 * `git rebase upstream/master`
 * `git checkout your-branch`
 * `git rebase master`
 * Fix any merge conflicts
 * `git push origin your-branch` (origin would be your GitHub repo or `your-github-username/boxstarter` in this case). You may need to `git push origin your-branch --force` to get the commits pushed. This is generally acceptable with topic branches not in the mainstream repository.

The only reasons a pull request should be closed and resubmitted are as follows:

  * When the pull request is targeting the wrong branch (this doesn't happen as often).
  * When there are updates made to the original by someone other than the original contributor (and the PR is not open for contributions). Then the old branch is closed with a note on the newer branch this supersedes #github_number.

## Other General Information
The helpers/utility functions that are available to the packages are what we consider the API. If you are working in the API, please note that you will need to maintain backwards compatibility. You should not remove or reorder parameters, only add optional parameters to the end. They should be named and not positional (we are moving away from positional parameters as much as possible).

If you reformat code or hit core functionality without an approval from a person on the Chocolatey Team, it's likely that no matter how awesome it looks afterwards, it will probably not get accepted. Reformatting code makes it harder for us to evaluate exactly what was changed.

If you do these things, it will be make evaluation and acceptance easy. Now if you stray outside of the guidelines we have above, it doesn't mean we are going to ignore your pull request. It will just make things harder for us.  Harder for us roughly translates to a longer SLA for your pull request.
