#!/usr/bin/env bash
set -e

# Set reasonable defaults for our environment variables
ARCH=${ARCH:-"x86_64"}
WEB_ROOT=${WEB_ROOT:-"/srv/http/repo-gitlab"}
REPO_NAME=${REPO_NAME:-"garuda"}
REPO_DIR=${REPO_DIR:-"$WEB_ROOT/$REPO_NAME/$ARCH"}

function check-env() {
  # Abort if any of these aren't set
  [[ -z "$PKG" ]] && echo "PKG is not set!" && exit 1

  return 0
}
function clean-duplicates() {
  set -euo pipefail

  if [[ ! -d "$REPO_DIR" ]]; then
    echo 'Deploying directory not found.'
    return 0
  fi

  pushd "${REPO_DIR}"

  local _DUPLICATED _TO_MV _U_SURE

  _DUPLICATED=$(
    # shellcheck disable=SC2010
    ls |
      grep -Po "^(.*)(?=(?:(?:-[^-]*){3}\.pkg\.tar(?>\.xz|\.zst)?)\.sig$)" |
      uniq -d
  )

  if [[ -z "${_DUPLICATED}" ]]; then
    echo "No duplicate packages were found!"
  else
    _TO_MV=$(
      echo "${_DUPLICATED[@]}" |
        awk '{print "find -name \""$1"*\" -printf \"%T@ %p\\n\" | sort -n | grep -Po \"\\.\\/"$1"(((-[^-]*){3}\\.pkg\\.tar(?>\\.xz|\\.zst)?))\\.sig$\" | head -n -1;"}' |
        bash |
        awk '{sub(/\.sig$/,"");print $1"\n"$1".sig"}'
    )

    echo "[!] Moving:"
    echo "${_TO_MV[*]}"

    echo "[!] Total: $(echo -n "${_TO_MV[*]}" | wc -l)"
    if [[ "${1:-}" == '-q' ]]; then
      _U_SURE='Y'
    else
      read -r -p "[?] Are you sure? [y/N] " _U_SURE
    fi

    case "${_U_SURE}" in
    [yY])
      # shellcheck disable=SC2086
      echo "${_TO_MV[@]}" | xargs mv -v -f -t ../archive/
      # Make sure we don't instantly delete them from archive if the package is too old
      echo "${_TO_MV[@]}" | xargs touch --no-create
      ;;
    esac
  fi

  popd # REPO_DIR

  return 0
}

function clean-archive() {
  set -euo pipefail

  # Let's save time!
  (clean-duplicates -q) || true

  if [[ ! -d "${REPO_DIR}/../archive" ]]; then
    echo 'Non-exiting archive directory'
    return 0
  fi

  pushd "${REPO_DIR}/../archive"

  find . -type f -mtime +7 -name '*' -execdir rm -- '{}' \; || true

  popd
  return 0
}

function clean-sigs() {
  set -euo pipefail

  local _TO_MV=()

  pushd "${REPO_DIR}"

  readarray -d '' _TO_MV < <(find . -name "*.pkg.tar.zst" -mmin +59 -exec sh -c '[[ ! -f "${1}.sig" ]]' -- "{}" \; -print0)
  readarray -d '' -O "${#_TO_MV[@]}" _TO_MV < <(find . -name "*.pkg.tar.zst.sig" -mmin +59 -exec sh -c '[[ ! -f "${1%.*}" ]]' -- "{}" \; -print0)

  if [[ -z "${_TO_MV:-}" ]]; then
    if [[ "${1:-}" != '-q' ]]; then
      echo '[!] Nothing to do...'
    fi
    exit 0
  fi

  echo '[!] Missing sig or archive:'
  printf '%s\n' "${_TO_MV[@]}"

  echo "[!] Total: ${#_TO_MV[@]}"
  if [[ "${1:-}" == '-q' ]]; then
    _U_SURE='Y'
  else
    read -r -p "[?] Are you sure? [y/N] " _U_SURE
  fi

  case "${_U_SURE}" in
  [yY])
    # shellcheck disable=SC2086
    echo "${_TO_MV[@]}" | xargs mv -v -f -t ../archive/
    # Make sure we don't instantly delete them from archive if the package is too old
    echo "${_TO_MV[@]}" | xargs touch --no-create
    ;;
  esac

  popd

  return 0
}

function sign() {
  # Sign our package using gpg
  gpg --detach-sign \
    --use-agent \
    --no-armor \
    --yes \
    "$PKG_DIR"/"$PKG"*.pkg.tar.zst

  return 0
}

function add-repo() {
  # Put files from our temporary upload directory into the repo directory
  mv "$PKG_DIR/$PKG"*.pkg.tar.{zst,zst.sig} "$REPO_DIR"

  # Add the package to the repo database
  repo-add -v "$REPO_DIR"/"$REPO_NAME".db.tar.zst "$REPO_DIR"/"$PKG"*.pkg.tar.zst

  return 0
}

function db-pkglist() {
  set -euo pipefail

  pushd "${REPO_DIR}"
  if (tar -tv --zstd \
    -f "${REPO_NAME}.db.tar.zst" |
    awk '/^d/{print $6}' >../pkgs.txt); then

    if [[ -e ../pkgs.files.txt ]]; then
      mv ../pkgs.files.txt ../pkgs.files.old.txt
    fi

    ls -- *.pkg.* >../pkgs.files.txt

    if [[ -e ../pkgs.files.old.txt ]]; then
      diff ../pkgs.files.old.txt ../pkgs.files.txt |
        grep '^[\<\>]' |
        deploy-notify "$@"
    fi

    echo "Database's package list dumped"
  else
    echo 'Failed to dump package list'
  fi
  popd # REPO_DIR

  return 0
}

function deploy-notify() {
  # Notify our deployment service that we've deployed a new package
  telegram-send --format markdown "$@"

  return 0
}

function clean-post-deploy() {
  set -euo pipefail

  (clean-archive -q) || true
  (clean-sigs -q) || true

  return 0
}

check-env
sign
add-repo
db-pkglist
clean-post-deploy
