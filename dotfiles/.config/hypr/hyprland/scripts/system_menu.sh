#!/usr/bin/env bash

OPTIONS="Lock\nSleep\nRestart\nShutdown"
CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu -p "System" -theme ~/.config/rofi/config.rasi)

case $CHOICE in
    Lock) hyprlock ;;
    Sleep) systemctl suspend ;;
    Restart) reboot ;;
    Shutdown) shutdown now ;;
esac
