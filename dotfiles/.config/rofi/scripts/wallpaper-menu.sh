#!/usr/bin/env bash

function get_wallpapers {
  local wallpapers wallpaper
  
  wallpapers=$(find "$HOME/Pictures/wallpapers" -type f \( -name "*.jpg" -o -name "*.png" \))

  for wallpaper in $wallpapers; do
    printf "%s\x00icon\x1f%s\n" "$(basename "$wallpaper")" "$wallpaper"
  done
}

CHOICE=$(get_wallpapers | rofi -dmenu -i -p "" -theme ~/.config/rofi/wallpaper.rasi)
if [[ -n "${CHOICE:-}" ]]; then
  cp "$HOME/Pictures/wallpapers/$CHOICE" "$HOME/.cache/current-wallpaper"
  swaybg -i "$HOME/.cache/current-wallpaper" -m fill
fi
