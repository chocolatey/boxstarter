Committers
============

<!-- TOC -->

- [Branch Targeting](#branch-targeting)
- [Summary](#summary)
- [Terminology](#terminology)
- [Review Process](#review-process)
    - [Receive new PR (pull request)](#receive-new-pr-pull-request)
    - [Initial PR Review](#initial-pr-review)
    - [Review the Code](#review-the-code)
    - [Accepting a PR](#accepting-a-pr)
- [Merging](#merging)

<!-- /TOC -->

## Branch Targeting

Please target the master branch. It makes it much easier to push the shiny green button on a pull request.

## Summary
We like to see folks contributing to Boxstarter. If you are a committer, we'd like to see you help from time to time with triage and the pull request process.

In all cases politeness goes a long way. Please thank folks for contributions - they are going out of their way to help make the code base better, or adding something they may personally feel is necessary for the code base.

Please be VERY familiar with [CONTRIBUTING](https://github.com/chocolatey/boxstarter/blob/master/CONTRIBUTING.md) and follow the process as well.

## Terminology
**Contributor** - A person who makes a change to the code base and submits a change set in the form of a pull request.

**Change Set** - A set of discrete commits which combined together form a contribution.  A change set takes the form of git commits and is submitted in the form of a pull request. Used interchangeably with "pull request".

**Committer** - A person responsible for reviewing a pull request and then making the decision what base branch to merge the change set into.

## Review Process
### Receive new PR (pull request)
 * A contributor sends a pull request.
 * A committer typically reviews it within a week or less to determine the feasibility of the changes.

### Initial PR Review
 * Did the user create a branch with these changes? If it is on their master, please ask them to review [CONTRIBUTING](https://github.com/chocolatey/boxstarter/blob/master/CONTRIBUTING.md).
 * Did the user reformat files and they should not have? Was is just white-space? You can try adding [?w=1](https://github.com/blog/967-github-secrets) to the URL on GitHub.
 * Are there tests? We really want any new contributions to contain tests so unless the committer believes this code really needs to be in the code base and is willing to write the tests, then we need to ask the contributor to make a good faith effort in adding test cases. Ask them to review the [contributing document](https://github.com/chocolatey/boxstarter/blob/master/CONTRIBUTING.md) and provide tests. **Note:** Some commits may be refactoring which wouldn't necessarily add additional test sets.
 * Is the code documented properly? Does this additional set of changes require changes to the [docs](https://boxstarter.org/WhyBoxstarter)?
 * Was this code warranted? Did the contributor follow the process of gaining approval for big change sets? If not please have them review the [contributing document](https://github.com/chocolatey/boxstarter/blob/master/CONTRIBUTING.md) and ask that they follow up with a case for putting the code into the code base on the mailing list.

### Review the Code
  * Does the code meet the naming conventions and formatting?
  * Is the code sound? Does it read well? Can you understand what it is doing without having to execute it? Principal of no clever hacks (need link).
  * Does the code do what the purpose of the pull request is for (and only that)?

### Accepting a PR
Once you have reviewed the initial items, and are not waiting for additional feedback or work by the contributor, give the thumbs up that it is ready for the next part of the process (merging).

Unless there is something wrong with the code, we don't ask contributors to rebase against master. They did the work to create the patch in the first place, asking them to unnecessarily come back and try to keep their code synced up with master is not an acceptable process.

## Merging
Once you have reviewed the change set and determined it is ready for merge, the next steps are to bring it local and evaluate the code further by actually working with it, running the tests locally and adding any additional commits or fix-ups that are necessary in a local branch.

When merging the user's contribution, it should be done with `git merge --log --no-ff` to create a merge commit so that in case there is an issue it becomes easier to revert later, and so that we can see where the code came from should we ever need to go find it later (more information on this can be found [here](https://www.kernel.org/pub/software/scm/git/docs/git-merge.html) and also a discussion on why this is a good idea [here](https://differential.com/insights/best-way-to-merge-a-github-pull-request/)).
