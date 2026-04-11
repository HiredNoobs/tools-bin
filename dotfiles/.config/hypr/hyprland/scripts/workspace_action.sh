#!/usr/bin/env bash
#
# Helper script for moving windows to different workspaces.

if [[ "${1-}" == "--help" || "${1-}" == "-h" || -z "${1-}" || -z "${2-}" ]]; then
  echo "Usage: $0 <dispatcher> <target>"
  exit 1
fi

DISPATCHER=$1
TARGET=$2

if [[ $TARGET =~ ^[0-9]+$ ]]; then
  CURRENT_WORKSPACE=$(hyprctl activeworkspace -j | jq -r '.id')
  TARGET_WORKSPACE=$(( ((CURRENT_WORKSPACE - 1) / 10) * 10 + TARGET ))
  hyprctl dispatch "$DISPATCHER" "$TARGET_WORKSPACE"
else
  hyprctl dispatch "$DISPATCHER" "$TARGET"
fi
