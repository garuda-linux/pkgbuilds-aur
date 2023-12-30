# Not so Chaotic-AUR

[![pipeline status](https://gitlab.com/garuda-linux/pkgsbuilds-aur/badges/main/pipeline.svg)](https://gitlab.com/garuda-linux/pkgsbuilds-aur/-/commits/main)
[![Commitizen friendly](https://img.shields.io/badge/commitizen-friendly-brightgreen.svg)](http://commitizen.github.io/cz-cli/)

WIP

## Overview

We use a combination of GitLab CI and [Chaotic Manager](https://gitlab.com/garuda-linux/tools/chaotic-manager) to manage this repository.

### GitLab CI

Important links:

- [Pipeline runs](https://gitlab.com/garuda-linux/chaotic-aur/-/pipelines)
  - Invididual stages and jobs are listed here
  - Scheduled builds appear as individual jobs of the "external" stage, linking to live-updating log output of the builds
- [Invididual jobs](https://gitlab.com/garuda-linux/chaotic-aur/-/jobs)

#### Jobs

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

## General information

- `.SRCINFO` **needs** to be available in each PKGBUILD folder for determining current versions, dependencies and other values

## Options

### .CI_CONFIG

The `.CI_CONFIG` file inside each package directory contains additional flags to control the pipelines and build processes with.

- `CI_IS_GIT_SOURCE`: By setting this to `1`, the `fetch-gitsrc` job will update `pkgver` of this package.
  This is useful for packages which use `pkgver()` to set their version without being having `-git` or another VCS package suffix.
- `CI_MANAGE_AUR`: By setting this variable to `1`, the CI will update the corresponding AUR repository at the end of a pipeline run if changes occurred.
- `CI_PKGREL`: Controls package bumps for all packages which don't have `CI_MANAGE_AUR` set to `1`. It increases `pkgrel` by `0.1` for every `+1` increase of this variable.
- `CI_PKGBUILD_SOURCE`: Sets the source for all PKGBUILD related files, used for pulling updated files from remote repositories

## Found any issue?

If any packaging issues or similar things occur, don't hesitate to report them via our issues section. You can click [here](https://gitlab.com/garuda-linux/pkgbuilds-aur/-/issues/new) to create a new one.

## Development setup

This repository features a NixOS flake, which may be used to set up the needed things like pre-commit hooks and checks, as well as needed utilities, automatically via [direnv](https://direnv.net/).
Needed are `nix` (the package manager) and [direnv](https://direnv.net/), after that, the environment may be entered by running `direnv allow`.
