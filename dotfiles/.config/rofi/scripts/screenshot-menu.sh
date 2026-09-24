#!/usr/bin/env bash

FULLSCREEN_INSTANT="󰄀 Fullscreen (instant)"
FULLSCREEN_DELAY="󱎫 Fullscreen (2s delay)"
SELECT_AREA_INSTANT=" Select Area (instant)"
SELECT_AREA_DELAY="󱎫 Select Area (2s delay)"

SCREENSHOT_DIR="$HOME/Pictures/screenshots"

OPTIONS="$FULLSCREEN_INSTANT\n$FULLSCREEN_DELAY\n$SELECT_AREA_INSTANT\n$SELECT_AREA_DELAY"
CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "$SCREENSHOT_DIR" -theme ~/.config/rofi/screenshot.rasi)

mkdir -p "$SCREENSHOT_DIR"

case "$CHOICE" in
  "$FULLSCREEN_INSTANT")
    FILE="$SCREENSHOT_DIR/full-$(date +%Y%m%d-%H%M%S)-$RANDOM.png"
    grim "$FILE"
    swappy -f "$FILE"
    ;;
  "$FULLSCREEN_DELAY")
    sleep 2
    FILE="$SCREENSHOT_DIR/full-$(date +%Y%m%d-%H%M%S)-$RANDOM.png"
    grim "$FILE"
    swappy -f "$FILE"
    ;;
  "$SELECT_AREA_INSTANT")
    FILE="$SCREENSHOT_DIR/snip-$(date +%Y%m%d-%H%M%S)-$RANDOM.png"
    grim -g "$(slurp)" "$FILE"
    swappy -f "$FILE"
    ;;
  "$SELECT_AREA_DELAY")
    sleep 2
    FILE="$SCREENSHOT_DIR/snip-$(date +%Y%m%d-%H%M%S)-$RANDOM.png"
    grim -g "$(slurp)" "$FILE"
    swappy -f "$FILE"
    ;;
esac
