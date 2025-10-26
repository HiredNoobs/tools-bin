#!/usr/bin/env bash
#
# Initial setup script.
# It should be fine to run multiple times or after the repo has been cloned
# but this is the script I run on fresh LXCs and VMs and I don't tend to run
# it again so YMMV.
#
# Does slightly different things depending on whether it's run as root or not.
#
# If run as root it does the following:
# 1) Installs general dependencies for the repo.
# 2) Creates a new user, by default this is "my" user (i.e. hirednoobs).
#    Note: You need to manually set a new password for this user with passwd.
# 3) Creates a file for that user in sudoers.d and gives them passwordless sudo.
# 4) Clones this repo in the new users home directory.
#
# If not running as root, the user will need sudo access, it does the following:
# 1) Installs general dependencies for the repo.
# 2) Clones this repo into the users home directory.
#
# Usage:
# curl -L https://bit.ly/HiredMove | bash -s [username]

set -euo pipefail

# movein.sh duplicates lib/logging.sh because it has to.
# Without these the script couldn't be curl'd for initial setup.
NO_COLOR="\033[0m"
INFO_COLOR="\033[1;32m"
ERR_COLOR="\033[0;31m"

function log_info() {
  echo -e "${INFO_COLOR}$1${NO_COLOR}"
}

function log_error() {
  echo -e "${ERR_COLOR}$1${NO_COLOR}"
}

# If root we use $1 or the default
# else we use the current user.
if [[ "$EUID" -eq 0 ]]; then
  USERNAME="${1:-hirednoobs}"
else
  USERNAME="$USER"
fi

REPO_URL="https://github.com/HiredNoobs/bin.git"
HOME_DIR="/home/$USERNAME"
BIN_DIR="$HOME_DIR/bin"

# TODO: Setup for Arch too :)
# I don't run this on Arch often but it might be nice to have.
if [[ "$EUID" -eq 0 ]]; then
  apt-get update -y
  apt-get install -y sudo git rsync

  if id "$USERNAME" &>/dev/null; then
    log_info "User '$USERNAME' already exists; skipping creation."
  else
    adduser --gecos "" --disabled-password "$USERNAME"
    usermod -aG sudo "$USERNAME"
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME"
    chmod 0440 "/etc/sudoers.d/$USERNAME"

    log_info "Created user '$USERNAME' and added to sudo group."
    log_info "Update the password for '$USERNAME' manually with 'passwd $USERNAME'."
  fi

  if [[ -d "$BIN_DIR/.git" ]]; then
    log_info "Updating existing repo in $BIN_DIR"
    sudo -u "$USERNAME" git -C "$BIN_DIR" pull --ff-only
  else
    log_info "Cloning $REPO_URL into $BIN_DIR"
    sudo -u "$USERNAME" git clone "$REPO_URL" "$BIN_DIR"
  fi
else
  sudo apt-get update -y
  sudo apt-get install -y sudo git rsync

  if [[ -d "$BIN_DIR/.git" ]]; then
    log_info "Updating existing repo in $BIN_DIR"
    git -C "$BIN_DIR" pull --ff-only
  else
    log_info "Cloning $REPO_URL into $BIN_DIR"
    git clone "$REPO_URL" "$BIN_DIR"
  fi
fi


