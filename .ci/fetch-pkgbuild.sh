#!/usr/bin/env bash

for dep in curl git jq shfmt; do
	command -v "$dep" &>/dev/null || echo "$dep is not installed!"
done

function read-variables() {
	if [[ "$1" == "old" ]]; then
		_OLDDESC=$(grep -oP '\spkgdesc\s=\s\K.*' "$package/.SRCINFO")
		_OLDINSTALL=$(grep -oP '\sinstall\s=\s\K.*' "$package/.SRCINFO")
		_OLDLICENSE=$(grep -oP '\slicense\s=\s\K.*' "$package/.SRCINFO")
		_OLDPKGREL=$(grep -oP '\spkgrel\s=\s\K.*' "$package/.SRCINFO")
		_OLDURL=$(grep -oP '\surl\s=\s\K.*' "$package/.SRCINFO")
		_OLDVER=$(grep -oP '\spkgver\s=\s\K.*' "$package/.SRCINFO")
		mapfile -t _OLDARCH < <(grep -oP '\sarch\s=\s\K.*' "$package/.SRCINFO")
		mapfile -t _OLDBACKUP < <(grep -oP '\sbackup\s=\s\K.*' "$package/.SRCINFO")
		mapfile -t _OLDCONFLICTS < <(grep -oP '\sconflicts\s=\s\K.*' "$package/.SRCINFO")
		mapfile -t _OLDDEPENDS < <(grep -oP '\sdepends\s=\s\K.*' "$package/.SRCINFO")
		mapfile -t _OLDMAKEDEPENDS < <(grep -oP '\smakedepends\s=\s\K.*' "$package/.SRCINFO")
		mapfile -t _OLDMD5SUMS < <(grep -oP '\smd5sums\s=\s\K.*' "$package/.SRCINFO")
		mapfile -t _OLDOPTDEPENDS < <(grep -oP '\soptdepends\s=\s\K.*' "$package/.SRCINFO")
		mapfile -t _OLDSHA1SUMS < <(grep -oP '\ssha1sums\s=\s\K.*' "$package/.SRCINFO")
		mapfile -t _OLDSHA256SUMS < <(grep -oP '\ssha256sums\s=\s\K.*' "$package/.SRCINFO")
		mapfile -t _OLDSHA512SUMS < <(grep -oP '\ssha512sums\s=\s\K.*' "$package/.SRCINFO")
		mapfile -t _OLDSOURCE < <(grep -oP '\ssource\s=\s\K.*' "$package/.SRCINFO")
	elif [[ "$1" == "new" ]]; then
		_NEWDESC=$(echo "$_NEWSRCINFO" | grep -oP '\spkgdesc\s=\s\K.*')
		_NEWINSTALL=$(echo "$_NEWSRCINFO" | grep -oP '\sinstall\s=\s\K.*')
		_NEWLICENSE=$(echo "$_NEWSRCINFO" | grep -oP '\slicense\s=\s\K.*')
		_NEWPKGREL=$(echo "$_NEWSRCINFO" | grep -oP '\spkgrel\s=\s\K.*')
		_NEWURL=$(echo "$_NEWSRCINFO" | grep -oP '\surl\s=\s\K.*')
		_NEWVER=$(echo "$_NEWSRCINFO" | grep -oP '\spkgver\s=\s\K.*')
		mapfile -t _NEWARCH < <(echo "$_NEWSRCINFO" | grep -oP '\sarch\s=\s\K.*')
		mapfile -t _NEWBACKUP < <(echo "$_NEWSRCINFO" | grep -oP '\sbackup\s=\s\K.*')
		mapfile -t _NEWCONFLICTS < <(echo "$_NEWSRCINFO" | grep -oP '\sconflicts\s=\s\K.*')
		mapfile -t _NEWDEPENDS < <(echo "$_NEWSRCINFO" | grep -oP '\sdepends\s=\s\K.*')
		mapfile -t _NEWMAKEDEPENDS < <(echo "$_NEWSRCINFO" | grep -oP '\smakedepends\s=\s\K.*')
		mapfile -t _NEWMD5SUMS < <(echo "$_NEWSRCINFO" | grep -oP '\smd5sums\s=\s\K.*')
		mapfile -t _NEWOPTDEPENDS < <(echo "$_NEWSRCINFO" | grep -oP '\soptdepends\s=\s\K.*')
		mapfile -t _NEWSHA1SUMS < <(echo "$_NEWSRCINFO" | grep -oP '\ssha1sums\s=\s\K.*')
		mapfile -t _NEWSHA256SUMS < <(echo "$_NEWSRCINFO" | grep -oP '\ssha256sums\s=\s\K.*')
		mapfile -t _NEWSHA512SUMS < <(echo "$_NEWSRCINFO" | grep -oP '\ssha512sums\s=\s\K.*')
		mapfile -t _NEWSOURCE < <(echo "$_NEWSRCINFO" | grep -oP '\ssource\s=\s\K.*')
	fi
}

function read-functions() {
	# We basically compare the set of available functions before and after sourcing
	# the PKGBUILD here, if they differ, the PKGBUILD needs to be reviewed
	local _OLDFUNCS _NEWFUNCS
	echo "$_NEWPKG" >/tmp/newpkgbuild
	_OLDFUNCS=$(grep -Pzo '[pkgver|package|build].*{((?:[^{}]*|(?R))*)}\n' "$package/PKGBUILD")
	_NEWFUNCS=$(grep -Pzo '[pkgver|package|build].*{((?:[^{}]*|(?R))*)}\n' /tmp/newpkgbuild)

	if [[ "${_OLDFUNCS[*]}" != "${_NEWFUNCS[*]}" ]]; then
		echo "Function changes detected..."
		((_NEEDS_REVIEW++))
		((_NEEDS_UPDATE++))
	else
		echo "No function changes detected..."
	fi
}

function exists-branch() {
	if git ls-remote --exit-code --heads origin "update-$package" &>/dev/null; then
		_BRANCH_EXISTS=1
	else
		_BRANCH_EXISTS=0
	fi
}

function classify-update() {
	# Used to determine whether the update changes integral parts of the
	# PKGBUILD, thus requiring a human review
	[[ "$_OLDDESC" != "$_NEWDESC" ]] && _DIFFS+=("pkgdesc")
	[[ "$_OLDINSTALL" != "$_NEWINSTALL" ]] && _DIFFS+=("install")
	[[ "$_OLDLICENSE" != "$_NEWLICENSE" ]] && _DIFFS+=("license")
	[[ "$_OLDPKGREL" != "$_NEWPKGREL" ]] && _DIFFS+=("pkgrel")
	[[ "$_OLDURL" != "$_NEWURL" ]] && _DIFFS+=("url")
	[[ "$_OLDVER" != "$_NEWVER" ]] && _DIFFS+=("pkgver")
	[[ "${_OLDARCH[*]}" != "${_NEWARCH[*]}" ]] && _DIFFS+=("arch")
	[[ "${_OLDBACKUP[*]}" != "${_NEWBACKUP[*]}" ]] && _DIFFS+=("backup")
	[[ "${_OLDCONFLICTS[*]}" != "${_NEWCONFLICTS[*]}" ]] && _DIFFS+=("conflicts")
	[[ "${_OLDDEPENDS[*]}" != "${_NEWDEPENDS[*]}" ]] && _DIFFS+=("depends")
	[[ "${_OLDMAKEDEPENDS[*]}" != "${_NEWMAKEDEPENDS[*]}" ]] && _DIFFS+=("makedepends")
	[[ "${_OLDMD5SUMS[*]}" != "${_NEWMD5SUMS[*]}" ]] && _DIFFS+=("md5sums")
	[[ "${_OLDOPTDEPENDS[*]}" != "${_NEWOPTDEPENDS[*]}" ]] && _DIFFS+=("optdepends")
	[[ "${_OLDPREPARE[*]}" != "${_NEWPREPARE[*]}" ]] && _DIFFS+=("prepare")
	[[ "${_OLDSHA1SUMS[*]}" != "${_NEWSHA1SUMS[*]}" ]] && _DIFFS+=("sha1sums")
	[[ "${_OLDSHA256SUMS[*]}" != "${_NEWSHA256SUMS[*]}" ]] && _DIFFS+=("sha256sums")
	[[ "${_OLDSHA512SUMS[*]}" != "${_NEWSHA512SUMS[*]}" ]] && _DIFFS+=("sha512sums")
	[[ "${_OLDSOURCE[*]}" != "${_NEWSOURCE[*]}" ]] && _DIFFS+=("source")

	if [[ ${_DIFFS[*]} != "" ]]; then
		echo "Variable changes detected: ${_DIFFS[*]}"
		((_NEEDS_UPDATE++))
	else
		echo "No variable changes detected..."
	fi

	for algorithm in sha1sums sha256sums sha512sums md5sums; do
		# shellcheck disable=2076
		if [[ "${_DIFFS[*]}" =~ "$algorithm" ]]; then
			_CURRENT_ALG="$algorithm"
		fi
	done

	# Somehow determine whether some of the changes are major
	# ~ to be improved
	if [[ "${#_DIFFS[@]}" -lt 4 ]]; then
		# shellcheck disable=2076
		[[ "${_DIFFS[*]}" =~ "pkgver" ]] &&
			[[ "${_DIFFS[*]}" =~ "$_CURRENT_ALG" ]] &&
			[[ "${_DIFFS[*]}" =~ "source" ]] &&
			return 0
	elif [[ "${#_DIFFS[@]}" -lt 3 ]]; then
		# shellcheck disable=2076
		[[ "${_DIFFS[*]}" =~ "pkgver" ]] &&
			[[ "${_DIFFS[*]}" =~ "$_CURRENT_ALG" ]] &&
			return 0
	elif [[ "${#_DIFFS[@]}" -lt 2 ]]; then
		# shellcheck disable=2076
		[[ "${_DIFFS[*]}" =~ "pkgrel" ]] &&
			return 0
	else
		((_NEEDS_REVIEW++))
	fi
}

function update_pkgbuild() {
	git clone "${_SOURCES[$package]}" "$_TMPDIR/source"

	# Switch to a new branch and put new files in place, in case non-trivial changes
	if [[ $_NEEDS_REVIEW -gt 0 ]]; then
		_TARGET_BRANCH="update-$package"
	else
		_TARGET_BRANCH=main
	fi

	cp -v "$_TMPDIR"/source/{*,.SRCINFO} "$package"

	# Only push if there are changes
	if ! git diff --exit-code --quiet; then
		git add "$package"

		# Commit and push the changes back to trigger a new pipeline run
		git commit -m "chore($package): ${_OLDVER}-${_OLDPKGREL} -> ${_NEWVER}-${_NEWPKGREL}"

		git push "$REPO_URL" HEAD:"$_TARGET_BRANCH" # Env provided via GitLab CI
		printf "\n\n"
	else
		printf "No changes detected, skipping!\n\n"
	fi
}

function create_mr() {
	# Taken from https://about.gitlab.com/2017/09/05/how-to-automatically-create-a-new-mr-on-gitlab-with-gitlab-ci/
	# Require a list of all the merge request and take a look if there is already
	# one with the same source branch
	local _COUNTBRANCHES _LISTMR
	_LISTMR=$(curl --silent "https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/merge_requests?state=opened" \
		--header "PRIVATE-TOKEN:${ACCESS_TOKEN}")
	_COUNTBRANCHES=$(echo "${_LISTMR}" | grep -o "\"source_branch\":\"${CI_COMMIT_REF_NAME}\"" | wc -l)

	if [ "${_COUNTBRANCHES}" == "0" ]; then
		_MR_EXISTS=0
	else
		_MR_EXISTS=1
	fi

	# The description of our new MR, we want to remove the branch after the MR has
	# been closed
	BODY="{
	\"project_id\": ${CI_PROJECT_ID},
	\"source_branch\": \"${_TARGET_BRANCH}\",
	\"target_branch\": \"main\",
	\"remove_source_branch\": true,
	\"force_remove_source_branch\": false,
	\"allow_collaboration\": true,
	\"subscribed\" : false,
	\"approvals_before_merge\": \"1\",
	\"title\": \"chore($package): ${_OLDVER}-${_OLDPKGREL} -> ${_NEWVER}-${_NEWPKGREL} [deploy $package]\",
	\"description\": \"The recent update of this package requires human reviewal!\",
	\"labels\": \"ci,human-review,update\"
	}"

	# No MR found, let's create a new one
	if [ "$_MR_EXISTS" == 0 ]; then
		curl -s -X POST "https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/merge_requests" \
			--header "PRIVATE-TOKEN:${ACCESS_TOKEN}" \
			--header "Content-Type: application/json" \
			--data "${BODY}" &&
			printf "Opened a new merge request: chore(%s): %s-%s -> %s-%s\n\n" "$package" "${_OLDVER}" "${_OLDPKGREL}" "${_NEWVER}" "${_NEWPKGREL}" ||
			printf "Failed to open a new merge request!\n\n"
	else
		printf "No new merge request opened due to an already existing MR.\n\n"
	fi
}

# Build a list of packages and sources
mapfile -t _PACKAGES < <(find . -mindepth 1 -type d -prune | sed -e '/.\./d' -e 's/.\///g')
declare -A _SOURCES

for package in "${_PACKAGES[@]}"; do
	_SOURCES["$package"]=$(grep -oP '^CI_PKGBUILD_SOURCE=\K.*$' "$package/.CI_CONFIG" || echo "none")
done

for package in "${!_SOURCES[@]}"; do
	echo "Checking $package..."
	_NEWPKG=$(curl -s "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$package")
	_NEWSRCINFO=$(curl -s "https://aur.archlinux.org/cgit/aur.git/plain/.SRCINFO?h=$package")

	# Get the latest tag from via AUR RPC endpoint, using a placeholder for git packages
	if [[ ! "$package" == *"-git"* ]]; then
		_LATEST_VERSION=$(curl -s "https://aur.archlinux.org/rpc/v5/info?arg%5B%5D=$package" | jq -r '.results.[0].Version')
	elif [[ -f "$package/.CI_CONFIG" ]] && grep -q "CI_IS_GIT_SOURCE=1" "$package/.CI_CONFIG"; then
		_LATEST_VERSION="git-src"
	else
		_LATEST_VERSION="git-src"
	fi

	# Check if a branch dedicated to updating the package already exists
	# if it does, switch to it to compare against the latest version
	exists-branch
	[ "$_BRANCH_EXISTS" == 1 ] && git checkout "update-$package"

	_NEEDS_REVIEW=0
	_NEEDS_UPDATE=0

	read-variables "old"
	read-variables "new"
	read-functions
	classify-update

	if [[ $_NEEDS_UPDATE == 0 ]]; then
		[[ $(git branch --show-current) != "main" ]] && git switch main
		printf "%s is up to date.\n\n" "$package"
		continue
	elif [[ $_NEEDS_REVIEW != 0 ]]; then
		# If review is needed, always create a merge request
		_TMPDIR=$(mktemp -d)
		update_pkgbuild
		create_mr
	elif [[ "$_LATEST" == "git-src" ]]; then
		# If no review is required and the package is a git package, do nothing
		# we generally just want to update the PKGBUILD in case its something like deps,
		# functions or makedep changing. Up-to-date pkgver is maintained by us.
		[[ $(git branch --show-current) != "main" ]] && git switch main
		printf "%s is managed by fetch-gitsrc, skipping.\n\n" "$package"
		continue
	elif [[ "$_OLDVER"-"$_OLDPKGREL" != "$_LATEST" ]]; then
		# Otherwise just push the version update to main
		_TMPDIR=$(mktemp -d)
		update_pkgbuild
	else
		printf "%s is up to date\n\n" "$package"
	fi

	[[ $(git branch --show-current) != "main" ]] && git switch main

	# Try to avoid rate limiting
	sleep 1
done
