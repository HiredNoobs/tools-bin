#!/usr/bin/env bash

TEMP=$(hyprctl hyprsunset temperature)

if [[ "$TEMP" -eq 6500 ]]; then
  hyprctl hyprsunset temperature 5000
else
  hyprctl hyprsunset temperature 6500
fi
