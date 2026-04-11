#!/usr/bin/env bash

OPTIONS="Fullscreen (instant)\nFullscreen (2s delay)\nSelect Area (instant)\nSelect Area (2s delay)"
CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu -p "Screenshots" -theme ~/.config/rofi/config.rasi)

case $CHOICE in
  "Fullscreen (instant)") grimblast --notify copysave screen ~/Downloads/$(date +%Y%m%d-%H%M%S).png ;;
  "Fullscreen (2s delay)") sleep 2 && grimblast --notify copysave screen ~/Downloads/$(date +%Y%m%d-%H%M%S).png ;;
  "Select Area (instant)") grimblast --freeze --notify copysave area ~/Downloads/$(date +%Y%m%d-%H%M%S).png ;;
  "Select Area (2s delay)") sleep 2 && grimblast --freeze --notify copysave area ~/Downloads/$(date +%Y%m%d-%H%M%S).png ;;
esac
