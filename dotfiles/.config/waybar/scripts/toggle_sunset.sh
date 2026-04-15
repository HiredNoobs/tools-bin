#!/usr/bin/env bash

TEMP=$(hyprctl hyprsunset temperature)

if [[ "$TEMP" -eq 6500 ]]; then
  hyprctl hyprsunset temperature 5000
else
  # Identity doesn't seem to reset the temp value,
  # hence we do it manually.
  # Does this make the identity call redundant?
  hyprctl hyprsunset temperature 6500
  hyprctl hyprsunset identity
fi
