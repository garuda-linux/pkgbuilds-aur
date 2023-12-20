#!/usr/bin/env bash

function parse-commit() {
    # Parse our commit message for which packages to build
    mapfile -t _PACKAGES < <(find . -mindepth 1 -type d -prune | sed -e '/.\./d' -e 's/.\///g')

    if [[ "$CI_COMMIT_MESSAGE" == *"[deploy all]"* ]]; then
        _PKG="full_run"
        echo "Requested a full routine run."
    elif [[ "$CI_COMMIT_MESSAGE" == *"[deploy"*"]"* ]]; then
        for package in "${_PACKAGES[@]}"; do
            [[ "$CI_COMMIT_MESSAGE" == *"[deploy $package]"* ]] &&
                _PKG="$package"
            echo "Requested package build for $package."
            break
        done
    else
        echo "No package to build found in commit message. Exiting." && exit 1
    fi
}

parse-commit

if [[ "$_PKG" == "full_run" ]]; then
    # shellcheck disable=SC2068
    /entry_point.sh schedule --repo "$BUILD_REPO" "${_PACKAGES[@]}"
else
    /entry_point.sh schedule --repo "$BUILD_REPO" "$_PKG"
fi
