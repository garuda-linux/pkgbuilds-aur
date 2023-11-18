#!/usr/bin/env bash
set -e

# Source env from arguments if not set
[[ -z "$PKG" ]] && PKG=$1
[[ -z "$PKG_DIR" ]] && PKG_DIR=$2
[[ -z "$REPO_DIR" ]] && REPO_DIR=$3
[[ -z "$REPO_NAME" ]] && REPO_NAME=$4

function check-env() {
  # Abort if any of these aren't set
  [[ -z "$PKG_DIR" ]] && echo "PKG_DIR is not set!" && exit 1
  [[ -z "$REPO_DIR" ]] && echo "REPO_DIR is not set!" && exit 1
  [[ -z "$REPO_NAME" ]] && echo "REPO_NAME is not set!" && exit 1
  [[ -z "$PKG" ]] && echo "PKG is not set!" && exit 1

  return 0
}

function sign() {
  # Sign our package using gpg
  gpg --detach-sign \
    --use-agent \
    --no-armor \
    --yes \
    "$PKG_DIR"/"$PKG".tar.zst
  
  return 0
}

function add-repo() {
  # Put files from our temporary upload directory into the repo directory
  mv "$PKG_DIR/$PKG"*.{tar.zst,tar.zst.sig} "$REPO_DIR"

  # Add the package to the repo database
  repo-add -v "$REPO_DIR"/"$REPO_NAME".db.tar.zst "$REPO_DIR"/"$PKG"*.pkg.tar.zst

  return 0
}

function deploy-notify() {
  # Notify our deployment service that we've deployed a new package
  telegram-send --format markdown "Deployed \`$PKG\` to \`$REPO_NAME\`"

  return 0
}

check-env
sign
add-repo
deploy-notify