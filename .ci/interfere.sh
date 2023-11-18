#!/usr/bin/env bash

function special-interference-needed() {
  local _INTERFERE
  _INTERFERE=0

  for interfere in PKGBUILD.append PKGBUILD.prepend interfere.patch prepare; do
    if [[ -e "./${PKG}/${interfere}" ]]; then
      echo "Interfering via ${interfere}.."
      ((_INTERFERE++)) || true
    fi
  done

  if [[ "${_INTERFERE}" -gt 0 ]]; then
    echo 'optdepends+=("chaotic-interfere")' >>./"${PKG}"/PKGBUILD
  else
    exit 0
  fi
}

function interference-generic() {
  set -euo pipefail -o functrace

  local PKG_NON_VCS

  # * Treats VCs
  if (echo "$PKG" | grep -qP '\-git$'); then
    extra_pkgs+=("git")
    PKG_NON_VCS="${PKG%-git}"
  fi
  if (echo "$PKG" | grep -qP '\-svn$'); then
    extra_pkgs+=("subversion")
    PKG_NON_VCS="${PKG%-svn}"
  fi
  if (echo "$PKG" | grep -qP '\-bzr$'); then
    extra_pkgs+=("breezy")
    PKG_NON_VCS="${PKG%-bzr}"
  fi
  if (echo "$PKG" | grep -qP '\-hg$'); then
    extra_pkgs+=("mercurial")
    PKG_NON_VCS="${PKG%-hg}"
  fi

  # * Multilib
  if (echo "$PKG" | grep -qP '^lib32-'); then
    extra_pkgs+=("multilib-devel")
  fi

  # * Special cookie for TKG kernels
  if (echo "$PKG" | grep -qP '^linux.*tkg'); then
    extra_pkgs+=("git")
  fi

  # * Read options
  if (grep -qPo "^options=\([a-z! \"']*(?<!!)ccache[ '\"\)]" "${PKG}/PKGBUILD"); then
    extra_pkgs+=("ccache")
  fi

  # * CHROOT Update
  pacman -Syu --noconfirm "${extra_pkgs[@]}"

  # * Add missing newlines at end of file
  # * Get rid of troublesome options
  {
    echo -e '\n\n\n'
    echo "PKGEXT='.pkg.tar.zst'"
    echo 'unset groups'
    echo 'unset replaces'
  } >>"${PKG}/PKGBUILD"

  # * Get rid of 'native optimizations'
  if (grep -qP '\-march=native' "${PKG}/PKGBUILD"); then
    sed -i'' 's/-march=native//g' "${PKG}/PKGBUILD"
  fi

  return 0
}

function interference-apply() {
  set -euo pipefail

  local _PREPEND _PKGBUILD

  interference-generic

  special-interference-needed

  # shellcheck source=/dev/null
  [[ -f "${PKG}/prepare" ]] &&
    source "${PKG}/prepare"

  if [[ -f "${PKG}/interfere.patch" ]]; then
    if patch -Np1 <"${PKG}/interfere.patch"; then
      echo 'Patches successfully applied.'
    else
      echo 'Ignoring patch failure...'
    fi
  fi

  if [[ -f "${PKG}/PKGBUILD.prepend" ]]; then
    # The worst one, but KISS and easier to maintain
    _PREPEND="$(cat "${PKG}/PKGBUILD.prepend")"
    _PKGBUILD="$(cat "${PKG}/PKGBUILD")"
    echo "$_PREPEND" >"${PKG}/PKGBUILD"
    echo "$_PKGBUILD" >>"${PKG}/PKGBUILD"
  fi

  [[ -f "${PKG}/PKGBUILD.append" ]] &&
    cat "${PKG}/PKGBUILD.append" >>"${PKG}/PKGBUILD"

  return 0
}

interference-apply
