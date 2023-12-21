#!/usr/bin/env bash

function parse-commit() {
    # Parse our commit message for which packages to build based on folder names
    mapfile -t _PACKAGES < <(find . -mindepth 1 -type d -prune | sed -e '/.\./d' -e 's/.\///g')

    if [[ "$CI_COMMIT_MESSAGE" == *"[deploy all]"* ]]; then
        echo "Requested a full routine run, which are not handled by this workflow." && exit 1
    elif [[ "$CI_COMMIT_MESSAGE" == *"[deploy"*"]"* ]]; then
        for package in "${_PACKAGES[@]}"; do
            if [[ "$CI_COMMIT_MESSAGE" == *"[deploy $package]"* ]]; then
                _PKG="$package"
                echo "Requested package build for $package."
                return 0
            fi
        done
        echo "No package to build found in commit message. Exiting." && exit 0
    else
        echo "No package to build found in commit message. Exiting." && exit 0
    fi
}

function prepare-env() {
    for dep in fakeroot namcap sudo; do
        command -v "$dep" &>/dev/null || echo "$dep is not installed!"
    done

    # Allow makepkg to work
    chown -R nobody:root "$CI_BUILDS_DIR"

    echo "Starting to prepare environment for a build of $_PKG..."
    cd "$_PKG" || echo "Failed to cd into $_PKG!" && exit 1
}

# This is required because makepkg does not like to be run as root and installation of
# packages is required for the build to succeed
function install_deps() {
    echo "Installing dependencies..."
    # shellcheck source=/dev/null
    source PKGBUILD

    if [[ -n "$depends" ]]; then
        for j in "${depends[@]}"; do
            pacman -Qi "$j" &>/dev/null && continue
            echo "Installing $j from deps..."
            pacman -S --noconfirm --needed "$j" &>/dev/null || echo "Failed to install $j, the build will probably fail!"
        done
    fi
    if [[ -n "$makedepends" ]]; then
        for j in "${makedepends[@]}"; do
            pacman -Qi "$j" &>/dev/null && continue
            echo "Installing $j from makedeps..."
            pacman -S --noconfirm --needed "$j" &>/dev/null || echo "Failed to install $j, the build will probably fail!"
        done
    fi
}

function build-pkg() {
    echo "Building the package..."
    sudo -Eu nobody makepkg -s --noconfirm --needed && exit 0 ||
        echo "Failed to build $_PKG, please have a look at why!" &&
        exit 1
}

function check-pkg() {
    echo "Checking the package integrity with namcap..."
    namcap -i ./*.pkg.tar.zst
}

parse-commit
prepare-env
install_deps
build-pkg
check-pkg
