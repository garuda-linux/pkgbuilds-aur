#!/usr/bin/env bash

function parse-commit() {
    # Parse our commit message for which packages to build based on folder names
    mapfile -t _PACKAGES < <(find . -mindepth 1 -type d -prune | sed -e '/.\./d' -e 's/.\///g')

    if [[ "$CI_COMMIT_MESSAGE" == *"[deploy all]"* ]]; then
        _PKG="full_run"
        echo "Requested a full routine run."
    elif [[ "$CI_COMMIT_MESSAGE" == *"[deploy"*"]"* ]]; then
        for package in "${_PACKAGES[@]}"; do
            if [[ "$CI_COMMIT_MESSAGE" == *"[deploy $package]"* ]]; then
                _PKG="$package"
                echo "Requested package build for $package."
                return 0
            fi
        done
        echo "No package to build found in commit message. Exiting." && exit 1
    else
        echo "No package to build found in commit message. Exiting." && exit 1
    fi
}

schedule-package() {
    # Schedule either a full run or a single package using chaotic-manager
    # the entry_point script also establishes a connection to our Redis server
    if [[ "$_PKG" == "full_run" ]]; then
        /entry_point.sh schedule --repo "$BUILD_REPO" "${_PACKAGES[@]}"
    else
        /entry_point.sh schedule --repo "$BUILD_REPO" "$_PKG"
    fi
}

parse-commit
schedule-package
