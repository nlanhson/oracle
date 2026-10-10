#!/usr/bin/env bash
# Oracle installer: fresh Arch → Oracle. Re-runnable. Never overwrites: backs up to ~/.oracle-backup/<stamp>/.
# On the Arch ISO it installs Arch first (archinstall.json, wipes /dev/nvme0n1); reboot, log in, run it again.
# curl -fsSL https://raw.githubusercontent.com/nlanhson/oracle/main/install.sh | bash [-s -- --dry-run] [--restore <backup>]
set -euo pipefail

REPO=${ORACLE_REPO:-https://github.com/nlanhson/oracle.git}
RAW=${ORACLE_RAW:-https://raw.githubusercontent.com/nlanhson/oracle/main}
DIR=$HOME/.local/share/oracle
BACKUP=$HOME/.oracle-backup/$(date +%Y%m%d-%H%M%S)
DRY=0 RESTORE=''

say() { printf '\e[36m::\e[0m %s\n' "$*"; }
die() { printf '\e[31m!! %s\e[0m\n' "$*" >&2; exit 1; }
run() { if ((DRY)); then printf '   would run: %s\n' "$*"; else "$@"; fi; }

# Arch ISO: one password for user son, root and disk → archinstall menu prefilled → Install. Args go to archinstall.
if [[ -d /run/archiso ]]; then
  say "Arch install: WIPES /dev/nvme0n1 (LUKS2 + btrfs). Check the menu, then Install."
  read -rsp "Password for son, root, disk: " PW </dev/tty; echo
  read -rsp "Again: " P2 </dev/tty; echo
  [[ -n $PW && $PW == "$P2" ]] || die "passwords empty or differ"
  H=$(openssl passwd -6 -stdin <<<"$PW")
  (umask 077; PW=$PW H=$H jq -n '{users: [{username: "son", enc_password: env.H, sudo: true}],
    root_enc_password: env.H, encryption_password: env.PW}' >/tmp/oracle-creds.json)
  exec archinstall --config-url "$RAW/archinstall.json" --creds /tmp/oracle-creds.json "$@" </dev/tty
fi

ARGS=("$@")
while (($#)); do
  case $1 in
    --dry-run) DRY=1 ;;
    --restore) RESTORE=$(realpath "${2:?--restore needs the backup folder}"); shift ;;
    *) die "unknown option $1" ;;
  esac
  shift
done

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
  exec bash "$SRC/install.sh" "${ARGS[@]}"
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

say "oracle command"
BIN=$HOME/.local/bin/oracle
if [[ $(readlink "$BIN") != "$DIR/bin/oracle" ]]; then
  if [[ -e $BIN ]]; then run mkdir -p "$BACKUP"; run mv "$BIN" "$BACKUP/"; fi
  run mkdir -p "${BIN%/*}"; run ln -s "$DIR/bin/oracle" "$BIN"
fi
M=$HOME/.local/state/oracle/migrations
run mkdir -p "$M"
for m in "$SRC"/migrations/*.sh; do [[ ! -f $m ]] || run touch "$M/${m##*/}"; done

S=(); ((DRY)) && S+=(--dry-run); [[ -z $RESTORE ]] || S+=(--restore "$RESTORE")
bash "$SRC/server/server.sh" "${S[@]}"

say "network (NetworkManager + systemd-resolved, active after reboot)"
run sudo systemctl enable NetworkManager systemd-resolved
WIFI=0
for s in systemd-networkd iwd dhcpcd netctl; do
  if systemctl is-enabled -q "$s" 2>/dev/null; then say "  disable $s"; run sudo systemctl disable "$s"; WIFI=1; fi
done
STUB=../run/systemd/resolve/stub-resolv.conf
[[ $(readlink /etc/resolv.conf) == "$STUB" ]] || run sudo ln -sf "$STUB" /etc/resolv.conf || say "  /etc/resolv.conf busy (container?), skipped"

say "disk unlock by TPM (no password at boot)"
L=/boot/loader/loader.conf
if ((!DRY)) && sudo test -f "$L" && ! sudo grep -q '^editor' "$L"; then run sudo sh -c "echo 'editor no' >> $L"; fi
MAP=$(findmnt -nvo SOURCE /)
DEV=$( ((DRY)) || sudo cryptsetup status "$MAP" 2>/dev/null | awk '$1 == "device:" {print $2}' || true)
if [[ -z $DEV || ! -e /dev/tpmrm0 ]]; then
  say "  skip: root not on LUKS, no TPM, or dry-run"
elif [[ $(sudo systemd-cryptenroll "$DEV") == *tpm2* ]]; then
  say "  already enrolled"
else
  UUID=$(sudo cryptsetup luksUUID "$DEV")
  sudo grep -q "$UUID" /etc/crypttab || echo "${MAP##*/} UUID=$UUID none tpm2-device=auto,x-initrd.attach" | sudo tee -a /etc/crypttab >/dev/null
  echo 'HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)' | sudo tee /etc/mkinitcpio.conf.d/oracle-tpm.conf >/dev/null
  sudo mkinitcpio -P
  read -rsp "Disk password: " PW </dev/tty; echo
  if [[ $(sudo systemd-cryptenroll "$DEV") != *recovery* ]]; then
    say "  RECOVERY KEY. Write it down; it unlocks the disk if the TPM ever fails:"
    printf %s "$PW" | sudo systemd-cryptenroll --unlock-key-file=/dev/stdin --recovery-key "$DEV"
  fi
  printf %s "$PW" | sudo systemd-cryptenroll --unlock-key-file=/dev/stdin --tpm2-device=auto --tpm2-pcrs=7 "$DEV"
fi

say "done. Reboot, log in on tty1 → Hyprland. Super+Return terminal, Super+B Brave. Later: oracle update"
((WIFI)) && say "Wi-Fi: after reboot run nmtui once to reconnect."
exit 0
