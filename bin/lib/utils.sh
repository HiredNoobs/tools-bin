#!/usr/bin/env bash
#
# General use utility functions, does nothing by itself.
# There shouldn't be any distro specific stuff in here...

# Gets the latest tag for a given github repo
function get_latest_release {
  curl -fsSL https://api.github.com/repos/"$1"/releases/latest | grep '"tag_name":' | cut -d'"' -f4
}

# Clones if not already cloned or pulls updates if exists
# Returns:
#   0 = no changes
#   1 = changes pulled or commit/tag checkout changed state
#   2 = errors
function get_latest_git {
  local repo target commit tag positional_args head_commit head_tag output changed
  positional_args=()
  changed=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --commit) commit="$2"; shift 2;;
      --tag) tag="$2"; shift 2;;
      -*) log_error "Unknown option: $1"; return 2;;
      *) positional_args+=("$1"); shift;;
    esac
  done

  set -- "${positional_args[@]}"
  repo=$1
  target=$2

  if [[ -n "${commit:-}" && -n "${tag:-}" ]]; then
    log_error "--commit and --tag cannot be used together"
    return 2
  fi

  if [[ -d "$target/.git" ]]; then
    head_commit=$(git -C "$target" rev-parse HEAD)
    head_tag=$(git -C "$target" tag --points-at HEAD)

    if [[ -n "${commit:-}" ]]; then
      if [[ "$commit" != "$head_commit" ]]; then
        git -C "$target" fetch origin "$commit" || return 2
        git -C "$target" checkout "$commit" || return 2
        changed=1
      fi
    elif [[ -n "${tag:-}" ]]; then
      # TODO: Add --force option to ignore this check
      if [[ "$tag" != "$head_tag" ]]; then
        git -C "$target" fetch origin "refs/tags/$tag:refs/tags/$tag" || return 2
        git -C "$target" checkout "tags/$tag" || return 2
        changed=1
      fi
    else
      output=$(git -C "$target" pull --ff-only 2>&1) || return 2
      if ! grep -q "Already up to date" <<< "$output"; then
        changed=1
      fi
    fi
  else
    if [[ -n "${commit:-}" ]]; then
      git clone --no-checkout "$repo" "$target" || return 2
      git -C "$target" fetch origin "$commit" || return 2
      git -C "$target" checkout "$commit" || return 2
    elif [[ -n "${tag:-}" ]]; then
      git clone --no-checkout "$repo" "$target" || return 2
      git -C "$target" fetch origin "refs/tags/$tag:refs/tags/$tag" || return 2
      git -C "$target" checkout "tags/$tag" || return 2
    else
      git clone "$repo" "$target" || return 2
    fi

    changed=1
  fi

  if [[ "$changed" == 1 ]]; then
    return 1
  else
    return 0
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

function first {
  echo "${1%% *}"
}

function list {
  local item i
  for item in "$@"; do
    for i in $item; do
      echo "  $i"
    done
  done
}

function count {
  echo "$1" | wc -w
}
