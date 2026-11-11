#!/bin/bash

choice=$(printf "Lock\nSleep\nReboot\nShutdown" | fuzzel --dmenu --lines=4 --width=15)
sure() { [ "$(printf 'Cancel\n%s' "$2" | fuzzel --dmenu --lines=2 --width=20 --prompt="$1  ")" = "$2" ]; } # Restart and Shut Down ask once, Cancel first

case "$choice" in
	Lock) hyprlock ;;
	Sleep) loginctl lock-session && systemctl suspend ;;
	Reboot) sure "Restart now?" Restart && systemctl reboot ;;
	Shutdown) sure "Shut down now?" "Shut Down" && systemctl poweroff ;;
esac
