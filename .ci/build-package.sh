#!/usr/bin/env bash

function exec-cmd() {
    # Execute a command in the container
    docker run -it "$_IMAGE" "$@"
}

function parse-commit() {
    # Parse our commit message for which packages to build
    mapfile -t _PACKAGES < <(find . -mindepth 1 -type d -prune | sed -e '/.\./d' -e 's/.\///g')

    if [[ "$CI_COMMIT_MESSAGE" == *"[deploy all]"* ]]; then
        _PKG="$package"
        echo "Requested a full routine run."
    elif [[ "$CI_COMMIT_MESSAGE" == *"[deploy"*"]"* ]]; then
        for package in "${_PACKAGES[@]}"; do
            [[ "$CI_COMMIT_MESSAGE" == *"[deploy $package]"* ]] &&
                _PKG="$package" &&
                echo "$_PKG" > deploy-pkg &&
                echo "Requested package build for $package."
            break
        done
    else
        echo "No package to build found in commit message. Exiting." && exit 1
    fi
}

function build-pkg() {
    _BUILD_DIR="$PWD/$_PKG"
    docker run -v "$_BUILD_DIR:/home/builder" \
        -w "/home/builder" \
        -e PACKAGE="$_PKG" \
        -e PACKAGER="Garuda Builder" \
        "$CI_REGISTRY_IMAGE"
}

parse-commit
build-pkg
