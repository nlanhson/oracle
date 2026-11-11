#!/bin/bash

choice=$(printf "Lock\nSleep\nReboot\nShutdown" | fuzzel --dmenu --lines=4 --width=15)

case "$choice" in
	Lock) hyprlock ;;
	Sleep) loginctl lock-session && systemctl suspend ;;
	Reboot) systemctl reboot ;;
	Shutdown) systemctl poweroff ;;
esac