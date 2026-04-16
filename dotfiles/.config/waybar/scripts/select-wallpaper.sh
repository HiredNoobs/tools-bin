#!/usr/bin/env bash

function get_wallpapers {
  local wallpapers wallpaper
  
  wallpapers=$(find "$HOME/Pictures/wallpapers" -type f \( -name "*.jpg" -o -name "*.png" \))

  for wallpaper in $wallpapers; do
    printf "%s\x00icon\x1f%s\n" "$(basename "$wallpaper")" "$wallpaper"
  done
}

CHOICE=$(get_wallpapers | rofi -dmenu -i -p "Wallpapers" -theme ~/.config/rofi/config.rasi)
swaybg -i "$HOME/Pictures/wallpapers/$CHOICE" -m fill
