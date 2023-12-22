#!/usr/bin/env bash

for dep in git rsync ssh; do
	command -v "$dep" &>/dev/null || echo "$dep is not installed!"
done

parse-gitdiff() {
    # Compare the last 2 commits
    _CURRENT_DIFF=$(git --no-pager diff --name-only HEAD~1..HEAD)

    # Set up required variables
    mapfile -t _PACKAGES < <(find . -mindepth 1 -type d -prune | sed -e '/.\./d' -e 's/.\///g')

    # Check whether relevant folders got changed
    for package in "${_PACKAGES[@]}"; do
        if [[ "$_CURRENT_DIFF" =~ "$package"/ ]]; then
            _PKG+=("$package")
        fi
    done

    if [[ "${#_PKG[@]}" == 0 ]]; then
        echo "No relevant package changes to push found, exiting gracefully." && exit 0
    fi
}

push-aur() {
    for package in "${_PKG[@]}"; do
        _CURRDIR=$(pwd)

        # Always set this to 0 to also handle missing .CI_CONFIG files gracefully
        CI_MANAGE_AUR=0
        # shellcheck source=/dev/null
        test -f "$_CURRDIR"/"$package"/.CI_CONFIG && source "$_CURRDIR"/"$package"/.CI_CONFIG

        if [[ "$CI_MANAGE_AUR" != 1 ]]; then
            printf "\nAUR management for %s is not enabled via .CI_CONFIG.\n" "$package" && continue
        fi

        printf "\nPushing %s to AUR...\n" "$package"

        _TMPDIR=$(mktemp -d)
        export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new"
        git clone "ssh://aur@aur.archlinux.org/$package.git" "$_TMPDIR"

        # Transfer all files except for CI / tools specific ones
        rsync --archive --verbose --delete --quiet \
            --exclude ".git" \
            --exclude ".CI_CONFIG" \
            --exclude "interfere.patch" \
            --exclude "prepare" \
            --exclude "PKGBUILD.append" \
            --exclude "PKGBUILD.prepend" \
            "$_CURRDIR/$package/" "$_TMPDIR"

        pushd "$_TMPDIR" || echo "Failed to change into $_TMPDIR!"

        # Only push if there are changes
        if ! git diff --exit-code --quiet; then
            git add .
            # Commit and push the changes to our new branch
            git commit -m "chore: update $package" \
                -m "This commit was automatically generated by the CI pipeline." \
                -m "The changelog can be found at https://gitlab.com/garuda-linux/pkgbuilds-aur." \
                -m "Logs of the corresponding pipeline run can be found here: $CI_PIPELINE_URL."

            # We force push here, because we want to overwrite in case of updates
            git push
        else
            echo "No changes detected, skipping!"
        fi

        popd || echo "Failed to change back into $_CURRDIR!"
    done
}

parse-gitdiff
push-aur
