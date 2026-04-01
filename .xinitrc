cd ~ &
dbus-update-activation-environment --all
eval $(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
export SSH_AUTH_SOCK
feh --bg-fill ~/wallpapers/YuruVibe.jpg &
wal -i ~/wallpapers/YuruVibe.jpg --backend colorz -n &
picom &
dunst &
slstatus &
greenclip daemon &
fcitx5 -d &
flameshot &
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
exec dwm
