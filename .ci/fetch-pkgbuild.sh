#!/usr/bin/env bash

for dep in curl git jq shfmt; do
	command -v "$dep" &>/dev/null || echo "$dep is not installed!"
done

function setup-workdir() {
	curl "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=${_PKGNAME[$_COUNTER]}" -o PKGBUILD
}

function read-variables() {
	if [[ "$1" == "old" ]]; then
		# shellcheck disable=1091
		source PKGBUILD
		_OLDARCH="$arch"
		_OLDBACKUP="$backup"
		_OLDBUILD="$build"
		_OLDCONFLICTS="$conflicts"
		_OLDDEPENDS="$depends"
		_OLDDESC="$pkgdesc"
		_OLDINSTALL="$install"
		_OLDLICENSE="$license"
		_OLDMAKEDEPENDS="$makedepends"
		_OLDMD5SUMS="$md5sums"
		_OLDOPTDEPENDS="$optdepends"
		_OLDPACKAGE="$package"
		_OLDPKGREL="$pkgrel"
		_OLDPREPARE="$prepare"
		_OLDSHA1SUMS="$sha1sums"
		_OLDSHA256SUMS="$sha256sums"
		_OLDSHA512SUMS="$sha512sums"
		_OLDSOURCE="$source"
		_OLDURL="$url"
		_OLDVER="$pkgver"
	elif [[ "$1" == "new" ]]; then
		# shellcheck disable=SC1090
		source <(echo "$_NEWPKG")
		_NEWARCH="$arch"
		_NEWBACKUP="$backup"
		_NEWBUILD="$build"
		_NEWCONFLICTS="$conflicts"
		_NEWDEPENDS="$depends"
		_NEWDESC="$pkgdesc"
		_NEWINSTALL="$install"
		_NEWLICENSE="$license"
		_NEWMAKEDEPENDS="$makedepends"
		_NEWMD5SUMS="$md5sums"
		_NEWOPTDEPENDS="$optdepends"
		_NEWPACKAGE="$package"
		_NEWPKGREL="$pkgrel"
		_NEWPREPARE="$prepare"
		_NEWSHA1SUMS="$sha1sums"
		_NEWSHA256SUMS="$sha256sums"
		_NEWSHA512SUMS="$sha512sums"
		_NEWSOURCE="$source"
		_NEWURL="$url"
		_NEWVER="$pkgver"
	fi
}

function read-functions() {
	# We basically compare the set of available functions before and after sourcing
	# the PKGBUILD here, if they differ, the PKGBUILD needs to be reviewed
	local _OLDFUNCS _NEWFUNCS

	# shellcheck disable=1091
	source PKGBUILD
	_OLDFUNCS=$(declare -f)

	# shellcheck disable=SC1090
	source <(echo "$_NEWPKG")
	_NEWFUNCS=$(declare -f)

	if [[ "${_OLDFUNCS[*]}" != "${_NEWFUNCS[*]}" ]]; then
		echo "Functions have changed, please review the PKGBUILD!"
		_NEEDS_REVIEW=1
		_NEEDS_UPDATE=1
	else
		echo "Functions have not changed, continuing!"
		_NEEDS_UPDATE=0
	fi
}

function exists-branch() {
	if git ls-remote --exit-code --heads origin "update-${_PKGNAME[$_COUNTER]}" &>/dev/null; then
		_BRANCH_EXISTS=1
	else
		_BRANCH_EXISTS=0
	fi
}

function classify-update() {
	# Used to determine whether the update changes integral parts of the
	# PKGBUILD, thus requiring a human review
	[[ "$_OLDARCH" != "$_NEWARCH" ]] && _DIFFS+=("arch")
	[[ "$_OLDBACKUP" != "$_NEWBACKUP" ]] && _DIFFS+=("backup")
	[[ "$_OLDBUILD" != "$_NEWBUILD" ]] && _DIFFS+=("build")
	[[ "$_OLDCONFLICTS" != "$_NEWCONFLICTS" ]] && _DIFFS+=("conflicts")
	[[ "$_OLDDEPENDS" != "$_NEWDEPENDS" ]] && _DIFFS+=("depends")
	[[ "$_OLDDESC" != "$_NEWDESC" ]] && _DIFFS+=("pkgdesc")
	[[ "$_OLDINSTALL" != "$_NEWINSTALL" ]] && _DIFFS+=("install")
	[[ "$_OLDLICENSE" != "$_NEWLICENSE" ]] && _DIFFS+=("license")
	[[ "$_OLDMAKEDEPENDS" != "$_NEWMAKEDEPENDS" ]] && _DIFFS+=("makedepends")
	[[ "$_OLDMD5SUMS" != "$_NEWMD5SUMS" ]] && _DIFFS+=("md5sums")
	[[ "$_OLDOPTDEPENDS" != "$_NEWOPTDEPENDS" ]] && _DIFFS+=("optdepends")
	[[ "$_OLDPACKAGE" != "$_NEWPACKAGE" ]] && _DIFFS+=("package")
	[[ "$_OLDPKGREL" != "$_NEWPKGREL" ]] && _DIFFS+=("pkgrel")
	[[ "$_OLDPREPARE" != "$_NEWPREPARE" ]] && _DIFFS+=("prepare")
	[[ "$_OLDSHA1SUMS" != "$_NEWSHA1SUMS" ]] && _DIFFS+=("sha1sums")
	[[ "$_OLDSHA256SUMS" != "$_NEWSHA256SUMS" ]] && _DIFFS+=("sha256sums")
	[[ "$_OLDSHA512SUMS" != "$_NEWSHA512SUMS" ]] && _DIFFS+=("sha512sums")
	[[ "$_OLDSOURCE" != "$_NEWSOURCE" ]] && _DIFFS+=("source")
	[[ "$_OLDURL" != "$_NEWURL" ]] && _DIFFS+=("url")
	[[ "$_OLDVER" != "$_NEWVER" ]] && _DIFFS+=("pkgver")

	if [[ ${_DIFFS[*]} != "" ]]; then
		echo "The following changes were detected: ${_DIFFS[*]}"
		_NEEDS_UPDATE=1
	else
		echo "No variable changes detected, continuing!"
		_NEEDS_UPDATE=0
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
			echo "No major changes detected, updating PKGBUILD!" &&
			_NEEDS_REVIEW=0
	elif [[ "${#_DIFFS[@]}" -lt 3 ]]; then
		# shellcheck disable=2076
		[[ "${_DIFFS[*]}" =~ "pkgver" ]] &&
			[[ "${_DIFFS[*]}" =~ "$_CURRENT_ALG" ]] &&
			echo "No major changes detected, updating PKGBUILD!" &&
			_NEEDS_REVIEW=0
	elif [[ "${#_DIFFS[@]}" -lt 2 ]]; then
		# shellcheck disable=2076
		[[ "${_DIFFS[*]}" =~ "pkgrel" ]] &&
			echo "No major changes detected, updating PKGBUILD!" &&
			_NEEDS_REVIEW=0
	else
		echo "Please review the changes and update the PKGBUILD accordingly!"
		_NEEDS_REVIEW=1
	fi
}

function update_pkgbuild() {
	git clone "https://aur.archlinux.org/${_PKGNAME[$_COUNTER]}.git" "$_TMPDIR/source"

	# Switch to a new branch and put new files in place, in case non-trivial changes
	if [[ $_NEEDS_REVIEW == 1 ]]; then
		_TARGET_BRANCH="update-${_PKGNAME[$_COUNTER]}"
	else
		_TARGET_BRANCH=main
	fi

	cp -v "$_TMPDIR"/source/* "$_CURRDIR"

	# Format the PKGBUILD
	shfmt -w "$_CURRDIR/PKGBUILD"

	# Only push if there are changes
	if ! git diff --exit-code --quiet; then
		git add .
		# Commit and push the changes to our new branch
		git commit -m "chore(${_PKGNAME[$_COUNTER]}): ${_OLDVER}-${_OLDPKGREL} -> ${_NEWVER}-${_NEWPKGREL} [deploy ${_PKGNAME[$_COUNTER]}]"

		# We force push here, because we want to overwrite in case of updates
		git push "$REPO_URL" HEAD:"$_TARGET_BRANCH" -f # Env provided via GitLab CI
	else
		echo "No changes detected, skipping!"
	fi
}

function create_mr() {
	# Taken from https://about.gitlab.com/2017/09/05/how-to-automatically-create-a-new-mr-on-gitlab-with-gitlab-ci/
	local TARGET_BRANCH=main

	# Require a list of all the merge request and take a look if there is already
	# one with the same source branch
	local _COUNTBRANCHES _LISTMR
	_LISTMR=$(curl --silent "https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/merge_requests?state=opened" \
		--header "PRIVATE-TOKEN:${ACCESS_TOKEN}")
	_COUNTBRANCHES=$(echo "${_LISTMR}" | grep -o "\"source_branch\":\"${CI_COMMIT_REF_NAME}\"" | wc -l)

	if [ "${_COUNTBRANCHES}" -eq "0" ]; then
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
	\"subscribed\" : true,
	\"approvals_before_merge\" 1,
	\"title\": \"chore(${_PKGNAME[$_COUNTER]}): ${_OLDVER}-${_OLDPKGREL} -> ${_NEWVER}-${_NEWPKGREL}\",
	\"description\": \"The recent update of this package requires humnan reviewal! 🧐\",
	\"labels\": \"ci,human-review,update\"
	}"

	# No MR found, let's create a new one
	if [ "$_MR_EXISTS" == 0 ]; then
		curl -X POST "https://gitlab.com/api/v4/projects/${CI_PROJECT_ID}/merge_requests" \
			--header "PRIVATE-TOKEN:${ACCESS_TOKEN}" \
			--header "Content-Type: application/json" \
			--data "${BODY}" &&
			echo "Opened a new merge request: chore(${_PKGNAME[$_COUNTER]}): ${_OLDVER} -> ${_NEWVER}" ||
			echo "Failed to open a new merge request!"
	else
		echo "No new merge request opened due to an already existing MR."
	fi
}

readarray -t _SOURCES < <(awk -F ' ' '{ print $1 }' ./SOURCES)
readarray -t _PKGNAME < <(awk -F ' ' '{ print $2 }' ./SOURCES)

_COUNTER=0
for package in "${_PKGNAME[@]}"; do
	# Get the latest tag from the GitLab API
	_LATEST=$(curl -s "https://aur.archlinux.org/rpc/v5/info?arg%5B%5D=${_PKGNAME[$_COUNTER]}" | jq '.results.[0].Version')
	_NEWPKG=$(curl -s "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=${_PKGNAME[$_COUNTER]}")

	# Check if a branch dedicated to updating the package already exists
	# if it does, switch to it to compare against the latest version
	exists-branch
	[ "$_BRANCH_EXISTS" == 1 ] && git checkout "update-${_PKGNAME[$_COUNTER]}"

	cd "${_PKGNAME[$_COUNTER]}" || echo "Failed to cd into ${_PKGNAME[$_COUNTER]}!"

	# shellcheck source=/dev/null
	source PKGBUILD || echo "Failed to source PKGBUILD for ${_PKGNAME[$_COUNTER]}!"

	read-variables "old"
	read-variables "new"
	read-functions
	classify-update

	if [[ $_NEEDS_UPDATE == 0 ]]; then
		continue
	elif [[ $_NEEDS_REVIEW == 1 ]]; then
		# If review is needed, always create a merge request
		_TMPDIR=$(mktemp -d)
		_CURRDIR=$(pwd)

		update_pkgbuild
		create_mr
	elif [[ "$_OLDVER"-"$_OLDPKGREL" != "$_LATEST" ]]; then
		# Otherwise just push the version update to main
		_TMPDIR=$(mktemp -d)
		_CURRDIR=$(pwd)

		update_pkgbuild
	else
		echo "${_PKGNAME[$_COUNTER]} is up to date"
	fi

	cd .. || echo "Failed to change back to the previous directory!"
	[[ $(git branch --show-current) != "main" ]] && git switch main

	((_COUNTER++))

	# Try to avoid rate limiting
	sleep 1
done
