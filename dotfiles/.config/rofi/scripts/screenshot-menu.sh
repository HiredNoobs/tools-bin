#!/usr/bin/env bash

FULLSCREEN_INSTANT="󰄀 Fullscreen (instant)"
FULLSCREEN_DELAY="󱎫 Fullscreen (2s delay)"
SELECT_AREA_INSTANT=" Select Area (instant)"
SELECT_AREA_DELAY="󱎫 Select Area (2s delay)"

SCREENSHOT_DIR="$HOME/Pictures/screenshots"

OPTIONS="$FULLSCREEN_INSTANT\n$FULLSCREEN_DELAY\n$SELECT_AREA_INSTANT\n$SELECT_AREA_DELAY"
CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "Screenshots ($SCREENSHOT_DIR)" -theme ~/.config/rofi/screenshot.rasi)

mkdir -p "$SCREENSHOT_DIR"

case $CHOICE in
  $FULLSCREEN_INSTANT) grimblast --notify copysave screen "$SCREENSHOT_DIR/$(date +%Y%m%d-%H%M%S).png";;
  $FULLSCREEN_DELAY) sleep 2 && grimblast --notify copysave screen "$SCREENSHOT_DIR/$(date +%Y%m%d-%H%M%S).png";;
  $SELECT_AREA_INSTANT) grimblast --freeze --notify copysave area "$SCREENSHOT_DIR/$(date +%Y%m%d-%H%M%S).png";;
  $SELECT_AREA_DELAY) sleep 2 && grimblast --freeze --notify copysave area "$SCREENSHOT_DIR/$(date +%Y%m%d-%H%M%S).png";;
esac
