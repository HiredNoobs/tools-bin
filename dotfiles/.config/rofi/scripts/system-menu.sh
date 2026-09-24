#!/usr/bin/env bash

LOGOUT="󰍃 Logout"
LOCK=" Lock"
SLEEP="⏾ Sleep"
REBOOT=" Reboot"
SHUTDOWN="⏻ Shutdown"

OPTIONS="$LOGOUT\n$LOCK\n$SLEEP\n$REBOOT\n$SHUTDOWN"
UPTIME="$(uptime -p | sed 's/up //g')"

CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "Uptime: $UPTIME" -theme ~/.config/rofi/system.rasi)

case $CHOICE in
  "$LOGOUT") hyprshutdown -t "Logging out..." ;;
  "$LOCK") hyprlock ;;
  "$SLEEP") systemctl suspend-then-hibernate || systemctl suspend ;;
  "$REBOOT") hyprshutdown -t "Rebooting..." --post-cmd "systemctl reboot" ;;
  "$SHUTDOWN") hyprshutdown -t "Shutting down..." --post-cmd "systemctl poweroff" ;;
esac
