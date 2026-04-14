#!/usr/bin/env bash

# Exit Menu using Rofi

OPTIONS=" Lock\n󰒲 Suspend\n Reboot\n⏻ PowerOff\n󰍃 LogOut"

SELECTED=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "Power Menu:")
# Extract only the action word
ACTION=$(echo "$SELECTED" | awk '{print $2}')

case "$ACTION" in
    Lock)
        slock
        ;;
    Suspend)
        systemctl suspend
        ;;
    Reboot)
        systemctl reboot
        ;;
    PowerOff)
        systemctl poweroff
        ;;
    LogOut)
        # Kill dwm
        pkill dwm
        ;;
esac
