# Top bar power button shut down on one click: now it opens the power menu (only changes the line if you never edited it)
F=$HOME/.config/waybar/config.jsonc
[[ -f $F ]] || exit 0
sed -i 's|"tooltip": "Logout",|"tooltip": "Power menu",|; s|"on-click": "systemctl poweroff".*|"on-click": "bash ~/.config/fuzzel/power-menu.sh"|' "$F"
pkill -USR2 -x waybar || true
