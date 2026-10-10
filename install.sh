#!/usr/bin/env bash
# Oracle installer: fresh Arch → Oracle. Re-runnable. Never overwrites: backs up to ~/.oracle-backup/<stamp>/.
# curl -fsSL https://raw.githubusercontent.com/nlanhson/oracle/main/install.sh | bash [-s -- --dry-run]
set -euo pipefail

REPO=${ORACLE_REPO:-https://github.com/nlanhson/oracle.git}
DIR=$HOME/.local/share/oracle
BACKUP=$HOME/.oracle-backup/$(date +%Y%m%d-%H%M%S)
DRY=0
[[ ${1:-} == --dry-run ]] && DRY=1

say() { printf '\e[36m::\e[0m %s\n' "$*"; }
die() { printf '\e[31m!! %s\e[0m\n' "$*" >&2; exit 1; }
run() { if ((DRY)); then printf '   would run: %s\n' "$*"; else "$@"; fi; }

((EUID != 0)) || die "run as your normal user, not root"
[[ -f /etc/arch-release ]] || die "not Arch Linux"
((DRY)) || sudo -v || die "your user needs sudo (archinstall: make the user a superuser)"

# Piped from curl (no checkout next to us): fetch repo, re-run from it.
SRC=$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd)
if [[ ! -f $SRC/packages.txt || ! -f $SRC/default/hypr/hyprland.lua ]]; then
  command -v git >/dev/null || { ((DRY)) && die "git missing; dry-run can't fetch repo"; sudo pacman -S --needed --noconfirm git; }
  if ((DRY)); then
    SRC=$(mktemp -d); git clone -q --depth 1 "$REPO" "$SRC"
  elif [[ -d $DIR/.git ]]; then
    git -C "$DIR" pull -q --ff-only; SRC=$DIR
  else
    git clone -q "$REPO" "$DIR"; SRC=$DIR
  fi
  exec bash "$SRC/install.sh" "$@"
fi

# Run from a checkout elsewhere (dev): point DIR at it.
if [[ $SRC != "$DIR" ]]; then
  if [[ ! -e $DIR ]]; then
    say "link $DIR → $SRC"; run mkdir -p "$(dirname "$DIR")"; run ln -s "$SRC" "$DIR"
  elif [[ $(readlink -f "$DIR") != "$SRC" ]]; then
    die "$DIR exists and is not this checkout. Run $DIR/install.sh instead."
  fi
fi

say "packages"
mapfile -t ALL < <(sed 's/#.*//; /^\s*$/d; s/\s//g' "$SRC/packages.txt")
PAC=(); AUR=()
for p in "${ALL[@]}"; do if [[ $p == aur:* ]]; then AUR+=("${p#aur:}"); else PAC+=("$p"); fi; done
if pacman -Q pulseaudio &>/dev/null; then
  say "  pulseaudio → pipewire"
  mapfile -t PA < <(pacman -Qq | grep '^pulseaudio')
  run sudo pacman -Rdd --noconfirm "${PA[@]}"
fi
run sudo pacman -Syu --needed --noconfirm "${PAC[@]}"
run sudo systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service

if ((${#AUR[@]})); then
  if ! command -v yay >/dev/null; then
    say "yay (AUR helper)"
    T=$(mktemp -d)
    run git clone -q https://aur.archlinux.org/yay-bin.git "$T/yay-bin"
    if ((DRY)); then run makepkg -si --noconfirm; else (cd "$T/yay-bin" && makepkg -si --noconfirm); fi
  fi
  run yay -S --needed --noconfirm "${AUR[@]}"
fi

say "hyprland config"
CFG=$HOME/.config/hypr/hyprland.lua
if [[ -f $CFG ]] && grep -q oracle-user-config "$CFG"; then
  say "  kept your $CFG"
else
  if [[ -e $CFG ]]; then
    say "  backup old $CFG → $BACKUP/"
    run mkdir -p "$BACKUP"; run mv "$CFG" "$BACKUP/"
  fi
  run mkdir -p "$(dirname "$CFG")"; run cp "$SRC/config/hypr/hyprland.lua" "$CFG"
fi

say "tty1 autostart"
LINE='[[ -f ~/.local/share/oracle/default/bash_profile ]] && . ~/.local/share/oracle/default/bash_profile'
BP=$HOME/.bash_profile
if [[ -f $BP ]] && grep -qF "$LINE" "$BP"; then
  say "  already in $BP"
else
  [[ -f $BP || ! -f /etc/skel/.bash_profile ]] || run cp /etc/skel/.bash_profile "$BP"
  if ((DRY)); then printf '   would append to %s: %s\n' "$BP" "$LINE"; else printf '\n%s\n' "$LINE" >>"$BP"; fi
fi

say "network (NetworkManager + systemd-resolved, active after reboot)"
run sudo systemctl enable NetworkManager systemd-resolved
WIFI=0
for s in systemd-networkd iwd dhcpcd netctl; do
  if systemctl is-enabled -q "$s" 2>/dev/null; then say "  disable $s"; run sudo systemctl disable "$s"; WIFI=1; fi
done
STUB=../run/systemd/resolve/stub-resolv.conf
[[ $(readlink /etc/resolv.conf) == "$STUB" ]] || run sudo ln -sf "$STUB" /etc/resolv.conf

say "done. Reboot, log in on tty1 → Hyprland. Super+Return terminal, Super+B Brave."
((WIFI)) && say "Wi-Fi: after reboot run nmtui once to reconnect."
exit 0
