#!/usr/bin/env bash

function setup-buildenv() {
    [[ -z $PACKAGER ]] && PACKAGER="Garuda Builder <team@garudalinux.org>"
    [[ -z $MAKEFLAGS ]] && MAKEFLAGS="-j$(nproc)"
    [[ -z $PACKAGE ]] && PACKAGE="all"

    echo "PACKAGER=\"$PACKAGER\"" >>/etc/makepkg.conf
    echo "MAKEFLAGS=$MAKEFLAGS" >>/etc/makepkg.conf

    # shellcheck disable=1091
    source PKGBUILD
    pacman -Syu --noconfirm --needed --asdeps "${makedepends[@]}" "${depends[@]}" || echo "Failed to install dependencies!"
}

function build-pkg() {
    sudo -u builder makepkg -s --noconfirm || echo "Failed to build package!"
}

setup-buildenv
build-pkg