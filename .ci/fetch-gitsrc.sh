#!/usr/bin/env bash

for dep in curl git; do
    command -v "$dep" &>/dev/null || echo "$dep is not installed!"
done

# Parse our commit message for which packages to build based on folder names
mapfile -t _PACKAGES < <(find . -mindepth 1 -type d -prune | sed -e '/.\./d' -e 's/.\///g')

# This is required for makepkg
# shellcheck source=/dev/null
source /etc/makepkg.conf
chown -R nobody:root "$CI_PROJECT_DIR"

# Get a list of all packages containing "-git"
IFS=$'\n'
_VCS_PKG=($(printf '%s\n' "${_PACKAGES[@]}" | sed '/-git/!d'))

for package in "${_VCS_PKG[@]}"; do
    printf "\nChecking %s...\n" "$package"
    pushd "$package" || echo "Failed to change into $package!"

    # Download and extract sources, skipping deps
    sudo -Eu nobody makepkg -do

    # Set up environment with required variables
    # shellcheck source=/dev/null
    source PKGBUILD
    srcdir=$(readlink -f src)

    # Run pkgver function of the sourced PKGBUILD
    _NEWVER=$(pkgver)
    sudo -Eu nobody makepkg --printsrcinfo | tee .SRCINFO &>/dev/null

	if ! git diff --exit-code --quiet; then
		git add PKGBUILD .SRCINFO
		git commit -m "chore($package): git-version $pkgver [deploy $package]"
		git push "$REPO_URL" HEAD:main || git pull --rebase && git push "$REPO_URL" HEAD:main # Env provided via GitLab CI
	else
		echo "Package already up-to-date."
	fi

    # Cleanup stuff left behind, like sources
    git reset --hard HEAD
    git clean -fd
done
