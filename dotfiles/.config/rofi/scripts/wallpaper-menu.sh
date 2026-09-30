#!/usr/bin/env bash

function get_wallpapers {
  local wallpaper

  while IFS= read -r -d '' wallpaper; do
    printf "%s\x00icon\x1f%s\n" "$(basename "$wallpaper")" "$wallpaper"
  done < <(find "$HOME/Pictures/wallpapers" -type f \( -name "*.jpg" -o -name "*.png" \) -print0)
}

CHOICE=$(get_wallpapers | rofi -dmenu -i -p "" -theme ~/.config/rofi/wallpaper.rasi)
if [[ -n "${CHOICE:-}" ]]; then
  mapfile -t OLD_PIDS < <(pgrep -x swaybg)

  cp "$HOME/Pictures/wallpapers/$CHOICE" "$HOME/.cache/current-wallpaper"
  setsid -f swaybg -i "$HOME/.cache/current-wallpaper" -m fill

  # Stop the old instances once the new one has drawn, avoids a flash of no wallpaper
  if [[ ${#OLD_PIDS[@]} -gt 0 ]]; then
    sleep 0.5
    kill "${OLD_PIDS[@]}"
  fi
fi
