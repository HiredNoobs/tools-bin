#!/usr/bin/env bash
#
# General use utility functions, does nothing by itself.
# There shouldn't be any distro specific stuff in here...

# Gets the latest tag for a given github repo
function get_latest_release {
  curl -fsSL https://api.github.com/repos/"$1"/releases/latest | grep '"tag_name":' | cut -d'"' -f4
}

# Clones if not already cloned or pulls updates if exists
function get_latest_git {
  local repo target
  repo=$1
  target=$2

  if [[ -d "$target/.git" ]]; then
    git -C $target pull
  else
    git clone $repo $target
  fi
}

# Creates a group if one doesn't already exist
function create_group {
  local group
  group=$1

  if ! getent group "$group" >/dev/null; then
    log_info "Creating group '$group'."
    sudo groupadd "$group"
  fi
}

# Adds a given user to a group if not already in the group
function add_user_to_group {
  local user group
  user=$1
  group=$2

  if ! id -nG "$user" | grep -qw "$group"; then
    sudo usermod -aG "$group" "$user"
  fi
}

function list {
  local item
  for item in "$@"; do
    echo "  $item"
  done
}

function count {
  echo "$1" | wc -w
}
