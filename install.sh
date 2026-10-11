#!/usr/bin/env bash
# Oracle installer: fresh Arch → Oracle. Re-runnable. Never overwrites: backs up to ~/.oracle-backup/<stamp>/.
# On the Arch ISO (or the Oracle ISO, which autostarts it) it installs Arch + Oracle in one pass (asks which disk to wipe).
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

# Arch ISO, one pass: internet (Wi-Fi prompt) → newest installer → disk → user/tz/keyboard → one password (user, root, disk) → archinstall
# → Oracle in chroot as user (temporary NOPASSWD sudo) → TPM enroll → reboot. Embedded USB copy only if GitHub unreachable.
if [[ -d /run/archiso && -z ${ORACLE_CHROOT:-} ]]; then
  net() { curl -fsI -m 10 --retry 3 --retry-all-errors https://archlinux.org >/dev/null 2>&1; }
  until net; do
    W=$(compgen -G '/sys/class/net/*/wireless' | head -1 || true); W=${W%/wireless}; W=${W##*/}
    [[ -n $W ]] || die "No internet. Plug in a network cable, then start the installer again."
    rfkill unblock wifi 2>/dev/null || true
    say "No internet. Wi-Fi networks:"
    iwctl station "$W" scan || true; sleep 4; iwctl station "$W" get-networks || true
    read -rp "Wi-Fi name: " SSID </dev/tty
    read -rsp "Wi-Fi password (empty if none): " WPW </dev/tty; echo
    P=(); [[ -z $WPW ]] || P=(--passphrase "$WPW")
    iwctl "${P[@]}" station "$W" connect "$SSID" || say "Could not connect. Try again."
  done
  if [[ -z ${ORACLE_LATEST:-} ]] && curl -fsSL -m 60 "$RAW/install.sh" -o /tmp/oracle-install.sh; then
    ORACLE_LATEST=1 exec bash /tmp/oracle-install.sh
  fi
  [[ -n ${ORACLE_LATEST:-} ]] || say "GitHub unreachable: using the installer copy on this USB (may be older)"

  if [[ -z ${ORACLE_DISK:-} ]]; then
    S=$(findmnt -no SOURCE /run/archiso/bootmnt || true)
    U=$(lsblk -no PKNAME "$S" 2>/dev/null || true)
    L=$(lsblk -dno NAME,SIZE,MODEL -e 7,11 | awk -v x=" ${S##*/} ${U//$'\n'/ } " '$1 !~ /^zram/ && !index(x, " " $1 " ")')
    [[ -n $L ]] || die "no disk found"
    say "Disks:"; sed 's/^/   /' <<<"$L"
    while :; do
      read -rp "Type the disk to ERASE for Oracle (everything on it is lost): " X </dev/tty || die "cancelled"
      X=${X#/dev/}; [[ -n $X ]] && awk '{print $1}' <<<"$L" | grep -qxF -- "$X" && break
      say "not in the list"
    done
    ORACLE_DISK=/dev/$X
  fi
  [[ -b $ORACLE_DISK ]] || die "$ORACLE_DISK is not a disk"
  MIB=$(($(blockdev --getsize64 "$ORACLE_DISK") / 1048576 - 1026)) # root = disk - 1 MiB gap - 1 GiB EFI - 1 MiB GPT backup
  ((MIB >= 30000)) || die "$ORACLE_DISK is too small (need 32 GB)"

  ask() { # ask <var> <prompt> <default> <check-cmd>: env var wins, Enter = default
    local v=${!1:-}
    while [[ -z $v ]] || ! $4 "$v"; do read -rp "$2 [$3]: " v </dev/tty; v=${v:-$3}; done
    printf -v "$1" %s "$v"
  }
  isuser() { [[ $1 =~ ^[a-z_][a-z0-9_-]{0,31}$ && $1 != root ]]; }
  istz() { [[ -f /usr/share/zoneinfo/$1 && $1 != */.* ]]; }
  iskb() { [[ -n $(find /usr/share/kbd/keymaps -name "$1.map.gz" -print -quit 2>/dev/null) ]]; }
  ask ORACLE_USER "Username (lowercase)" "" isuser
  ask ORACLE_TZ "Time zone" "$(curl -fsS -m 5 'http://ip-api.com/line/?fields=timezone' 2>/dev/null || echo UTC)" istz
  ask ORACLE_KB "Keyboard layout" us iskb
  U=$ORACLE_USER
  read -rsp "Password for $U, root, disk: " PW </dev/tty; echo
  read -rsp "Again: " P2 </dev/tty; echo
  [[ -n $PW && $PW == "$P2" ]] || die "passwords empty or differ"
  H=$(openssl passwd -6 -stdin <<<"$PW")
  (umask 077; PW=$PW H=$H jq -n --arg u "$U" '{users: [{username: $u, enc_password: env.H, sudo: true}],
    root_enc_password: env.H, encryption_password: env.PW}' >/tmp/oracle-creds.json)
  curl -fsSL -m 60 "$RAW/archinstall.json" -o /tmp/oracle-arch.json || cp /root/oracle/archinstall.json /tmp/oracle-arch.json
  jq --arg d "$ORACLE_DISK" --argjson m "$MIB" --arg tz "$ORACLE_TZ" --arg kb "$ORACLE_KB" '.timezone = $tz | .locale_config.kb_layout = $kb
    | .disk_config.device_modifications[0] |= (.device = $d | .partitions[1].size.value = $m)' \
    /tmp/oracle-arch.json >/tmp/oracle-config.json
  say "Arch → $ORACLE_DISK (wiped: 1G /boot, rest LUKS2 btrfs)"
  archinstall --config /tmp/oracle-config.json --creds /tmp/oracle-creds.json --silent </dev/tty && mountpoint -q /mnt \
    || die "archinstall failed (log: /var/log/archinstall/install.log)"
  rm -f /tmp/oracle-creds.json

  say "Oracle (inside the new system)"
  SUDO=/mnt/etc/sudoers.d/zz-oracle-install
  trap 'rm -f "$SUDO"' EXIT
  install -m440 /dev/stdin "$SUDO" <<<"$U ALL=(ALL) NOPASSWD: ALL"
  cp "${BASH_SOURCE[0]:-}" /mnt/var/tmp/oracle-install.sh
  ORACLE_CHROOT=1 arch-chroot /mnt su "$U" -c 'bash /var/tmp/oracle-install.sh' </dev/null || die "Oracle install failed"
  rm -f "$SUDO" /mnt/var/tmp/oracle-install.sh
  ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
  for f in /var/lib/iwd/*.psk; do # Wi-Fi known here → NetworkManager
    s=${f##*/}; s=${s%.psk}; p=$(sed -n 's/^Passphrase=//p' "$f" 2>/dev/null || true)
    [[ -n $p && $s != =* ]] || continue
    printf '[connection]\nid=%s\ntype=wifi\n[wifi]\nssid=%s\n[wifi-security]\nkey-mgmt=wpa-psk\npsk=%s\n' "$s" "$s" "$p" \
      | install -Dm600 /dev/stdin "/mnt/etc/NetworkManager/system-connections/$s.nmconnection"
  done

  if grep -q tpm2-device /mnt/etc/crypttab; then
    say "disk unlock by TPM (no password at boot)"
    DEV=$(cryptsetup status root | awk '$1 == "device:" {print $2}')
    printf %s "$PW" | systemd-cryptenroll --unlock-key-file=/dev/stdin --tpm2-device=auto --tpm2-pcrs=7 "$DEV"
    say "RECOVERY KEY. Write it down now; it unlocks the disk if the TPM ever fails:"
    printf %s "$PW" | systemd-cryptenroll --unlock-key-file=/dev/stdin --recovery-key "$DEV"
  else
    say "no TPM: type the disk password at each boot"
  fi
  sync
  say "Done. Remove the USB stick, press Enter to restart. Log in as $U."
  read -r </dev/tty
  reboot
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
((DRY)) || sudo true || die "your user needs sudo (archinstall: make the user a superuser)"

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

say "ghostty + tmux config"
ucfg() { # ucfg <file> <include line>: user file with include, only if missing
  if [[ -e $1 ]]; then say "  kept your $1"; else run mkdir -p "${1%/*}"; ((DRY)) || printf '%s\n# your changes below\n' "$2" >"$1"; fi
}
ucfg "$HOME/.config/ghostty/config" "config-file = $DIR/default/ghostty/config"
ucfg "$HOME/.config/tmux/tmux.conf" "source-file $DIR/default/tmux.conf"

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

say "battery charge limit (change: oracle battery <20-100>)"
BU=/etc/systemd/system/oracle-battery.service
if ((!DRY)) && [[ ! -f /etc/oracle/battery-limit ]]; then echo 50 | sudo install -Dm644 /dev/stdin /etc/oracle/battery-limit; fi
if ((!DRY)) && ! grep -qF '$$f' "$BU" 2>/dev/null; then
  sudo tee "$BU" >/dev/null <<'EOF'
[Unit]
Description=Oracle battery charge limit
[Service]
Type=oneshot
ExecStart=/usr/bin/sh -c 'for f in /sys/class/power_supply/BAT*/charge_control_end_threshold; do [ -w "$$f" ] && cat /etc/oracle/battery-limit >"$$f"; done; true'
[Install]
WantedBy=multi-user.target
EOF
fi
N=(); [[ -d /run/systemd/system && -z ${ORACLE_CHROOT:-} ]] && N=(--now)
run sudo systemctl enable "${N[@]}" oracle-battery.service

say "lid closed → screen off, keeps running"
if ((!DRY)) && ! cmp -s "$SRC/system/oracle-lid" /usr/local/bin/oracle-lid; then sudo install -Dm755 "$SRC/system/oracle-lid" /usr/local/bin/oracle-lid; sudo systemctl try-restart oracle-lid.service 2>/dev/null || true; fi
if ((!DRY)) && [[ ! -f /etc/systemd/system/oracle-lid.service ]]; then
  printf '[Unit]\nDescription=Oracle: backlight off while the lid is closed\n[Service]\nExecStart=/usr/local/bin/oracle-lid\nRestart=always\n[Install]\nWantedBy=multi-user.target\n' |
    sudo tee /etc/systemd/system/oracle-lid.service >/dev/null
fi
run sudo systemctl enable "${N[@]}" oracle-lid.service

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
  if [[ -n ${ORACLE_CHROOT:-} ]]; then
    say "  key: enrolled by the USB installer next"
  else
    read -rsp "Disk password: " PW </dev/tty; echo
    if [[ $(sudo systemd-cryptenroll "$DEV") != *recovery* ]]; then
      say "  RECOVERY KEY. Write it down; it unlocks the disk if the TPM ever fails:"
      printf %s "$PW" | sudo systemd-cryptenroll --unlock-key-file=/dev/stdin --recovery-key "$DEV"
    fi
    printf %s "$PW" | sudo systemd-cryptenroll --unlock-key-file=/dev/stdin --tpm2-device=auto --tpm2-pcrs=7 "$DEV"
  fi
fi

say "done. Reboot, log in on tty1 → Hyprland. Super+Return terminal, Super+B Brave. Later: oracle update"
((WIFI)) && say "Wi-Fi: after reboot run nmtui once to reconnect."
exit 0
