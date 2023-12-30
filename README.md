# Not so Chaotic-AUR

[![pipeline status](https://gitlab.com/garuda-linux/pkgsbuilds-aur/badges/main/pipeline.svg)](https://gitlab.com/garuda-linux/pkgsbuilds-aur/-/commits/main)
[![Commitizen friendly](https://img.shields.io/badge/commitizen-friendly-brightgreen.svg)](http://commitizen.github.io/cz-cli/)

This repository contains PKGBUILDs for core packages of Garuda, which are sourced from AUR and therefore not maintained by us.
Additionally, it serves as repository for "trusted" or "verified" packages due to the fact that updates are only getting deployed after passing a suite of checks for human reviewal.
It is operated on GitLab due to making extensive use of its CI and has a read-only GitHub mirror.

## Scope of this repository

The general idea is to have a supervised set of AUR packages, which are getting deployed to our `garuda` repository.
Before creating this repository, all packages were sourced from Chaotic-AUR, which blindly builds AUR packages, meaning that users are meant to check PKGBUILDs before installing packages.
It serves as central point for all packages, which are supervised by us and therefore safe to use without having to check any PKGBUILD before installation.
To achieve this goal, any update to AUR PKGBUILDs will be checked against the latest reviewed (and therefore trusted) PKGBUILD.
In case of minor changes (`pkgver`, `pkgrel` or `checksums`), updates will be deployed automatically.
Once major changes (everything else but the before mentioned, as well as function changes) were detected, an MR with the updated PKGBUILD will automatically be created for human reviewal.
Once the changes were determined to be acceptable, either a team member or trusted user may merge the changes, resulting in a deployment of the updated package.

## Found any issue?

Please report any packaging issues to the AUR maintainer so every user of the AUR may benefit from fixes.
For problems related to Garuda, CI pipelines or the repository itself, you can click [here](https://gitlab.com/garuda-linux/pkgbuilds-aur/-/issues/new) to create a new issue.

## How to contribute?

We highly appreciate contributions of any sort! 😊 This repository allows two ways of contributing.

### Improvements to scripts, CI and tooling

To contribute fixes related to CI, scripts or other things, please follow these steps:

- [Create a fork of this repository](https://gitlab.com/garuda-linux/pkgbuilds/-/forks/new).
- Clone your fork locally ([short git tutorial](https://rogerdudler.github.io/git-guide/)).
- Add the desired changes to PKGBUILDs or source code.
- Ensure [shellcheck](https://www.shellcheck.net) and [shfmt](https://github.com/patrickvane/shfmt) report no issues with the changed files
  - The needed dependencies need to be installed before, eg. via `sudo pacman -S shfmt shellcheck`
  - Run the `lint.sh` script via `bash ./.ci/lint.sh` check the code
  - Automatically apply certain suggestions via `bash ./ci/lint.sh apply`
- Commit using a [conventional commit message](https://www.conventionalcommits.org/en/v1.0.0/#summary) and push any changes back to your fork.
  - The [commitizen](https://github.com/commitizen-tools/commitizen) application helps with creating a fitting commit message.
    You can install it via [pip](https://pip.pypa.io/) as there is currently no package in Arch repos: `pip install --user -U Commitizen`.
    Then proceed by running `cz commit` in the cloned folder.
- [Create a new merge request at our main repository](https://gitlab.com/garuda-linux/pkgbuilds/-/merge_requests/new).
- Check if any of the pipeline runs fail and apply eventual suggestions.

We will then review the changes and eventually merge them.

### Reviewing MRs for updated packages

Since CI will create MR for any package update which requires human review, we also need people to review those changes.
If you are interested in being one of them, please let us know via email (team at garudalinux dot org) or the forum.

## GitLab CI

Important links:

- [Pipeline runs](https://gitlab.com/garuda-linux/pkgbuilds-aur/-/pipelines)
  - Invididual stages and jobs are listed here
  - Scheduled builds appear as individual jobs of the "external" stage, linking to live-updating log output of the builds
- [Invididual jobs](https://gitlab.com/garuda-linux/pkgbuilds-aur/-/jobs)

### General information

- Generally deployments will automatically happen if changes in any package folder occur.
  Additionally, deployments may be triggered by adding `[deploy $pkgname]` to the commit message.
- A half-hourly pipeline schedule will check for PKGBUILD updates, as well as new commits for packages which dynamically generate their version from git repositories.

### Options

#### .CI_CONFIG

The `.CI_CONFIG` file inside each package directory contains additional flags to control the pipelines and build processes with.

- `CI_GIT_COMMIT`: Used by CI to determine whether the latest commit changed. Used by `fetch-gitsrc` to schedule new builds.
- `CI_IS_GIT_SOURCE`: By setting this to `1`, the `fetch-gitsrc` job will check out the latest git commit of the source and compare it with the value recorded in `CI_GIT_COMMIT`.
  If it differs, schedules a build.
  This is useful for packages which use `pkgver()` to set their version without being having `-git` or another VCS package suffix.
- `CI_MANAGE_AUR`: By setting this variable to `1`, the CI will update the corresponding AUR repository at the end of a pipeline run if changes occurred (omitting CI-related files)
- `CI_PKGREL`: Controls package bumps for all packages which don't have `CI_MANAGE_AUR` set to `1`. It increases `pkgrel` by `0.1` for every `+1` increase of this variable.
- `CI_PKGBUILD_SOURCE`: Sets the source for all PKGBUILD related files, used for pulling updated files from remote repositories

#### Managing AUR packages

AUR packages can also be managed via this repository in an automated way using `.CI_CONFIG`. See the above section for details.

### Jobs

These generally execute scripts found in the `.ci` folder.

- Check PKGBUILD:
  - Checks PKGBUILD for superficial issues via `namcap` and `aura`
- Check rebuild:
  - Checks whether packages known to be causing rebuilds have been updated
  - Updates pkgrel for affected packages and pushes changes back to this repo
  - This triggers another pipeline run which schedules the corresponding builds
- Fetch Git sources:
  - Updates PKGBUILDs versions, which are derived from git commits and pushes changes back to this repo
  - This also triggers another pipeline run
- Lint:
  - Lints scripts, configs and PKGBUILDs via a set of linters
- Manage AUR:
  - Checks .CI_CONFIG in each PKGBUILDs folder for whether a package is meant to be managed on the AUR side
  - Clones the AUR repo and updates files with current versions of this repo
  - Pushes changes back
- Schedule package:
  - Checks for a list of commits between HEAD and "scheduled" tag
  - Checks whether a "[deploy]" string exists in the commit message or PKGBUILD directories changed
  - In either case a list of packages to be scheduled for a build gets created
  - Schedules all changed packages for a build via Chaotic Manager

### Chaotic Manager

This tool is distributed as Docker containers and consists of a pair of manager and builder instances.

- Manager: `registry.gitlab.com/garuda-linux/tools/chaotic-manager/manager`
- Builder: `registry.gitlab.com/garuda-linux/tools/chaotic-manager/builder`
  - This one contains the actual logic behind package builds (seen [here](https://gitlab.com/garuda-linux/tools/chaotic-manager/-/tree/main/builder-container?ref_type=heads)) known from infra 3.0 like `interfere.sh`, `database.sh` etc.
  - Picks packages to build from the Redis instance managed by the manager instance

The manager is used by GitLab CI in the `schedule-package` job, scheduling packages by adding it to the build queue.
The builder can be used by any machine capable of running the container. It will pick available jobs from our central Redis instance.

## Development setup

This repository features a NixOS flake, which may be used to set up the needed things like pre-commit hooks and checks, as well as needed utilities, automatically via [direnv](https://direnv.net/).
Needed are `nix` (the package manager) and [direnv](https://direnv.net/), after that, the environment may be entered by running `direnv allow`.
