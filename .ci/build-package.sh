#!/usr/bin/env bash

for dep in mkarchroot makechrootpkg; do
    command -v "$dep" &>/dev/null || echo "$dep is not installed!"
done

function setup-buildenv() {
    # https://wiki.archlinux.org/title/DeveloperWiki:Building_in_a_clean_chroot
    mkdir -p /build/chroot
    _CHROOT=/build/chroot
    _CHROOT_EXEC="arch-nspawn $_CHROOT/root"

    mkarchroot "$_CHROOT/root" base-devel || echo "failed to make chroot!" && exit 1

    PACKAGER='Garuda Builder <team@garudalinux.org>'
    MAKEFLAGS="-j$(nproc)"

    printf "PACKAGER=%s\nMAKEFLAGS=%s" "$PACKAGER" "$MAKEFLAGS" >"$_CHROOT/root/etc/makepkg.conf"

    # Prepare chroot for our purposes
    "$_CHROOT_EXEC" <<EOF
pacman-key --init 
pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com 
pacman-key --lsign-key 3056513887B78AEB
pacman --noconfirm -U 'https://geo-mirror.chaotic.cx/chaotic-aur/chaotic-'{keyring,mirrorlist}'.pkg.tar.zst'
echo "[multilib]" >>/etc/pacman.conf && echo "Include = /etc/pacman.d/mirrorlist" >>/etc/pacman.conf
echo -e "[garuda]\\nInclude = /etc/pacman.d/chaotic-mirrorlist\\n[chaotic-aur]\\nInclude = /etc/pacman.d/chaotic-mirrorlist" >>/etc/pacman.conf 
echo "" >>/etc/pacman.conf
pacman -Syu --noconfirm
EOF
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
                echo "Requested package build for $package."
                break
        done
    else
        echo "No package to build found in commit message. Exiting." && exit 1
    fi


}

function build-pkg() {
    cd "$_PKG" || echo "Could't change into PKGBUILD directory!" && exit 2
    makechrootpkg -c -r "$_CHROOT" || echo "Failed to build package!" && exit 3
}

parse-commit
setup-buildenv
build-pkg