#!/usr/bin/env bash

# YouTube Music Rofi control wrapper using playerctl

OPTIONS="󰐊 Play/Pause\n󰒭 Next\n󰒮 Previous"

SELECTED=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "YouTube Music:" -theme ~/.config/rofi/powermenu.rasi)

# Extract only the action word
ACTION=$(echo "$SELECTED" | awk '{print $2}')

case "$ACTION" in
    "Play/Pause")
        playerctl -p youtube-music play-pause || playerctl -p youtube-music,%any play-pause
        ;;
    "Next")
        playerctl -p youtube-music next || playerctl -p youtube-music,%any next
        ;;
    "Previous")
        playerctl -p youtube-music previous || playerctl -p youtube-music,%any previous
        ;;
esac
