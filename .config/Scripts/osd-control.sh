#!/usr/bin/env bash

# OSD Control Script for Volume and Brightness
# Usage: osd-control.sh [vol_up|vol_down|vol_mute|bri_up|bri_down]

ACTION="$1"
STEP=5

# Notifications
NOTIFY="notify-send -h string:x-canonical-private-synchronous:osd -t 1500"

case "$ACTION" in
    vol_up)
        # Increase volume by STEP% using wpctl
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ "${STEP}%+"
        VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2 * 100)}')
        $NOTIFY "     Volume: ${VOL}%"
        ;;
    vol_down)
        # Decrease volume by STEP% using wpctl
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "${STEP}%-"
        VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2 * 100)}')
        $NOTIFY "     Volume: ${VOL}%"
        ;;
    vol_mute)
        # Toggle mute
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        MUTED=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED && echo "Muted" || echo "Unmuted")
        if [ "$MUTED" = "Muted" ]; then
            $NOTIFY "󰖁     Volume Muted"
        else
            VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2 * 100)}')
            $NOTIFY "     Volume: ${VOL}%"
        fi
        ;;
    bri_up)
        # Increase brightness
        brightnessctl set ${STEP}%+
        BRI=$(brightnessctl get)
        MAX=$(brightnessctl max)
        PERC=$((BRI * 100 / MAX))
        $NOTIFY "󰃠  Brightness: ${PERC}%"
        ;;
    bri_down)
        # Decrease brightness
        brightnessctl set ${STEP}%-
        BRI=$(brightnessctl get)
        MAX=$(brightnessctl max)
        PERC=$((BRI * 100 / MAX))
        $NOTIFY "󰃟  Brightness: ${PERC}%"
        ;;
    *)
        echo "Usage: $0 {vol_up|vol_down|vol_mute|bri_up|bri_down}"
        exit 1
        ;;
esac
