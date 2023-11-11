#!/usr/bin/env bash

for dep in curl git jq; do
	command -v "$dep" &>/dev/null || echo "$dep is not installed!"
done

read-variables() {
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
		_NEWPKG=$(curl "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=${_PKGNAME[$i]}")
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

classify-update() {
	# Used to determine whether the update changes integral parts of the
	# PKGBUILD, thus requiring a human review
	# shellcheck disable=SC1090
	_NEWPKG=$(curl "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=${_PKGNAME[$i]}")

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

	echo "The following changes were detected: ${_DIFFS[*]}"

	for i in sha1sums sha256sums sha512sums md5sums; do
		# shellcheck disable=2076
		if [[ "${_DIFFS[*]}" =~ "$i" ]]; then
			_CURRENT_ALG="$i"
		fi
	done

	# Somehow determine whether some of the changes are major
	# ~ to be improved
	if [[ "${#_DIFFS[@]}" -lt 4 ]]; then
		# shellcheck disable=2076
		[[ "${_DIFFS[*]}" =~ "pkgver" ]] &&
			[[ "${_DIFFS[*]}" =~ "$_CURRENT_ALG" ]] &&
			[[ "${_DIFFS[*]}" =~ "source" ]] &&
			echo "No major detected, updating PKGBUILD!" &&
			_NEEDS_REVIEW=0
	elif [[ "${#_DIFFS[@]}" -lt 3 ]]; then
		# shellcheck disable=2076
		[[ "${_DIFFS[*]}" =~ "pkgver" ]] &&
			[[ "${_DIFFS[*]}" =~ "$_CURRENT_ALG" ]] &&
			echo "No major detected, updating PKGBUILD!" &&
			_NEEDS_REVIEW=0
	elif [[ "${#_DIFFS[@]}" -lt 2 ]]; then
		# shellcheck disable=2076
		[[ "${_DIFFS[*]}" =~ "pkgrel" ]] &&
			echo "No major detected, updating PKGBUILD!" &&
			_NEEDS_REVIEW=0
	else
		echo "Please review the changes and update the PKGBUILD accordingly!"
		_NEEDS_REVIEW=1
	fi

}

update_pkgbuild() {
	git clone "https://aur.archlinux.org/${_PKGNAME[$i]}.git" "$_TMPDIR/source"

	cp -v $_TMPDIR/source/* "$_CURRDIR"
}

readarray -t _SOURCES < <(awk -F ' ' '{ print $1 }' ./SOURCES)
readarray -t _PKGNAME < <(awk -F ' ' '{ print $2 }' ./SOURCES)

i=0
for package in "${_SOURCES[@]}"; do
	# Get the latest tag from the GitLab API
	_LATEST=$(curl -s "https://aur.archlinux.org/rpc/v5/info?arg%5B%5D=${_PKGNAME[$i]}" | jq '.results.[0].Version')

	cd "${_PKGNAME[$i]}" || echo "Failed to cd into ${_PKGNAME[$i]}!"

	# shellcheck disable=SC1091
	source PKGBUILD || echo "Failed to source PKGBUILD for ${_PKGNAME[$i]}!"

	if [[ "$pkgver" != "$_LATEST" ]]; then
		# Create a temporary directory to work with
		_TMPDIR=/tmp #$(mktemp -d)
		_CURRDIR=$(pwd)

		read-variables "old"
		read-variables "new"
		classify-update
		[[ $_NEEDS_REVIEW != 1 ]] && update_pkgbuild
	else
		echo "${_PKGNAME[$i]} is up to date"
	fi

	cd .. || echo "Failed to change back to the previous directory!"
	i=$((i + 1))

	# Try to avoid rate limiting
	sleep 5
done
