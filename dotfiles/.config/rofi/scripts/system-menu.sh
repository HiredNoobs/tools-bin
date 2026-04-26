#!/usr/bin/env bash

LOGOUT=" Logout"
LOCK=" Lock"
SLEEP=" Sleep"
REBOOT=" Reboot"
SHUTDOWN=" Shutdown"

OPTIONS="$LOGOUT\n$LOCK\n$SLEEP\n$REBOOT\n$SHUTDOWN"
UPTIME="$(uptime -p | sed 's/up //g')"

CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "Uptime: $UPTIME" -theme ~/.config/rofi/config.rasi -theme-str "entry { enabled: false; }")

case $CHOICE in
  $LOGOUT) hyprctl dispatch exit ;;
  $LOCK) hyprlock ;;
  $SLEEP) systemctl suspend-then-hibernate ;;
  $REBOOT) systemctl reboot ;;
  $SHUTDOWN) systemctl poweroff ;;
esac
