#!/usr/bin/env bash
set -euo pipefail

# This script is used to determine which packages to build based on the recent commits and run necessary checks
declare -A PACKAGES=()

function populate_commit_info() {
    COMMITS=()
    COMMIT_MESSAGES=()

    # We rely on the "scheduled" tag to be present in the repo to determine which commits to parse
    if ! [ "$(git tag -l "scheduled")" ]; then
        # If not present, we assume only the latest commit to be relevant
        COMMITS=("$(git rev-parse HEAD)")
        mapfile -t CHANGED_FILES < <(git diff-tree --no-commit-id --name-only -r HEAD)
    else
        # If present, we parse all commits between the "scheduled" tag and HEAD
        # This is required because CI may sometimes run on multiple commits at once,
        # resulting in only one pipeline run for multiple commits
        mapfile -t COMMITS < <(git rev-list scheduled..HEAD)
        mapfile -t CHANGED_FILES < <(git diff-tree --no-commit-id --name-only -r scheduled..HEAD)
    fi

    # Check if the array of commits is empty
    if [ ${#COMMITS[@]} -eq 0 ]; then
        echo "No commits detected since last CI run."
    fi

    # Get commit messages for each commit
    for commit in "${COMMITS[@]}"; do
        COMMIT_MESSAGES+=("$(git log --format=%B -n 1 "$commit")")
    done
}

function parse_commit_messages() {
    for i in "${!COMMIT_MESSAGES[@]}"; do
        local message="${COMMIT_MESSAGES[$i]}"
        local commit="${COMMITS[$i]}"
        local regex="\[deploy ([a-z0-9_ -]+)\]"
        if [[ "$message" =~ $regex ]]; then
            local potential_packages
            mapfile -t potential_packages <<< "${BASH_REMATCH[1]}"
            for package in "${potential_packages[@]}"; do
                case "$package" in
                    all)
                        PACKAGES["all"]=1
                        echo "Rebuild of all packages requested via commit message (${commit:0:7})."
                        return;
                        ;;
                    *)
                        if [ -d "$package" ]; then
                            PACKAGES["$package"]=1
                            echo "Rebuild of $package requested via commit message (${commit:0:7})."
                        else
                            echo "FATAL: Package $package requested but does not exist! Remove the package from the commit message (${commit:0:7}) and force push." >&2
                            exit 1
                        fi
                        ;;
                esac
            done
        fi
    done
}

function parse_changed_files() {
    declare -A CHANGED_ROOT_FOLDERS

    for file in "${CHANGED_FILES[@]}"; do
        # Exclude folders starting with a dot
        if [[ "${file:0:1}" == "." ]]; then
            continue
        fi

        # Extract the root folder of the changed file
        if [[ "$file" =~ ^([a-z0-9_-]+)/ ]]; then
            local folder="${BASH_REMATCH[1]}"
            if [ -d "$folder" ]; then
                CHANGED_ROOT_FOLDERS["$folder"]=1
            fi
        fi
    done

    for folder in "${!CHANGED_ROOT_FOLDERS[@]}"; do
        PACKAGES["$folder"]=1
        echo "Executing rebuild of $folder due to changes in the folder."
    done
}

# Populate the array with commit info we need here
populate_commit_info

# Parse commit messages
parse_commit_messages

# Parse changed files
parse_changed_files

# Check if we have any packages to build
if [ ${#PACKAGES[@]} -eq 0 ]; then
    echo "No packages to build, exiting gracefully."
else
    # Check if we have to build all packages
    if [[ -v "PACKAGES[all]" ]]; then
        "$(dirname "$(realpath "$0")")"/schedule-packages.sh all
    else
        "$(dirname "$(realpath "$0")")"/schedule-packages.sh "${!PACKAGES[@]}"
    fi
fi

git tag -f scheduled
git push --atomic -f origin refs/tags/scheduled