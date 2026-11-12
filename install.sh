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
step() { printf '\n\e[1mStep %s of 3 · %s\e[0m\n' "$1" "$2"; }
run() { if ((DRY)); then printf '   would run: %s\n' "$*"; else "$@"; fi; }

# Arch ISO, one pass: internet (Wi-Fi prompt) → newest installer → disk → user/tz/keyboard → one password (user, root, disk) → archinstall
# → Oracle in chroot as user (temporary NOPASSWD sudo) → TPM enroll → reboot. Embedded USB copy only if GitHub unreachable.
if [[ -d /run/archiso && -z ${ORACLE_CHROOT:-} ]]; then
  net() { curl -fsI -m 10 --retry 3 --retry-all-errors https://archlinux.org >/dev/null 2>&1; }
  until net; do
    W=$(compgen -G '/sys/class/net/*/wireless' | head -1 || true); W=${W%/wireless}; W=${W##*/}
    [[ -n $W ]] || die "No internet and no Wi-Fi card found. Plug in a network cable, then start the installer again."
    rfkill unblock wifi 2>/dev/null || true
    say "No internet yet. Pick your Wi-Fi from the list below (Ctrl+C stops the installer)."
    iwctl station "$W" scan || true; sleep 4; iwctl station "$W" get-networks || true
    read -rp "Wi-Fi name (type it as shown): " SSID </dev/tty
    read -rsp "Wi-Fi password (typing is hidden, leave empty if none): " WPW </dev/tty; echo
    P=(); [[ -z $WPW ]] || P=(--passphrase "$WPW")
    iwctl "${P[@]}" station "$W" connect "$SSID" || say "Could not connect. Check the name and password, then try again."
  done
  if [[ -z ${ORACLE_LATEST:-} ]] && curl -fsSL -m 60 "$RAW/install.sh" -o /tmp/oracle-install.sh; then
    ORACLE_LATEST=1 exec bash /tmp/oracle-install.sh
  fi
  [[ -n ${ORACLE_LATEST:-} ]] || say "Could not reach GitHub: using the installer copy on this USB (it may be a little older). This is fine."

  if [[ -z ${ORACLE_DISK:-} ]]; then
    S=$(findmnt -no SOURCE /run/archiso/bootmnt || true)
    U=$(lsblk -no PKNAME "$S" 2>/dev/null || true)
    L=$(lsblk -dno NAME,SIZE,MODEL -e 7,11 | awk -v x=" ${S##*/} ${U//$'\n'/ } " '$1 !~ /^zram/ && !index(x, " " $1 " ")')
    [[ -n $L ]] || die "No disk found. Check that the drive is connected, then start the installer again."
    step 1 "Choose the disk"
    say "Disks:"; sed 's/^/   /' <<<"$L"
    while :; do
      read -rp "Type the disk to ERASE for Oracle (everything on it is lost): " X </dev/tty || die "Cancelled. Nothing was changed."
      X=${X#/dev/}; [[ -n $X ]] && awk '{print $1}' <<<"$L" | grep -qxF -- "$X" && break
      say "That is not in the list. Type one of the names above, like nvme0n1."
    done
    ORACLE_DISK=/dev/$X
  fi
  [[ -b $ORACLE_DISK ]] || die "$ORACLE_DISK is not a disk. Use a name from the disk list."
  MIB=$(($(blockdev --getsize64 "$ORACLE_DISK") / 1048576 - 4098)) # root = disk - 1 MiB gap - 4 GiB EFI (kernels for boot-menu snapshots) - 1 MiB GPT backup
  ((MIB >= 30000)) || die "$ORACLE_DISK is too small: Oracle needs at least 32 GB. Pick a bigger disk."

  ask() { # ask <var> <prompt> <default> <check-cmd>: env var wins, Enter = default
    local v=${!1:-}
    while [[ -z $v ]] || ! $4 "$v"; do read -rp "$2 [$3]: " v </dev/tty; v=${v:-$3}; done
    printf -v "$1" %s "$v"
  }
  isuser() { [[ $1 =~ ^[a-z_][a-z0-9_-]{0,31}$ && $1 != root ]]; }
  istz() { [[ -f /usr/share/zoneinfo/$1 && $1 != */.* ]]; }
  iskb() { [[ -n $(find /usr/share/kbd/keymaps -name "$1.map.gz" -print -quit 2>/dev/null) ]]; }
  step 2 "About you"
  say "Letters, digits, - and _ only. Press Enter to accept the suggestion in [brackets]."
  ask ORACLE_USER "Username (lowercase)" "" isuser
  ask ORACLE_TZ "Time zone" "$(curl -fsS -m 5 'http://ip-api.com/line/?fields=timezone' 2>/dev/null || echo UTC)" istz
  ask ORACLE_KB "Keyboard layout" us iskb
  U=$ORACLE_USER
  step 3 "Password"
  say "One password for your login, administrator rights and the disk. Typing is hidden."
  read -rsp "Password for $U, root, disk: " PW </dev/tty; echo
  read -rsp "Again: " P2 </dev/tty; echo
  [[ -n $PW && $PW == "$P2" ]] || die "The two passwords were empty or different. Start the installer again and type the same password twice."
  H=$(openssl passwd -6 -stdin <<<"$PW")
  (umask 077; PW=$PW H=$H jq -n --arg u "$U" '{users: [{username: $u, enc_password: env.H, sudo: true}],
    root_enc_password: env.H, encryption_password: env.PW}' >/tmp/oracle-creds.json)
  curl -fsSL -m 60 "$RAW/archinstall.json" -o /tmp/oracle-arch.json || cp /root/oracle/archinstall.json /tmp/oracle-arch.json
  jq --arg d "$ORACLE_DISK" --argjson m "$MIB" --arg tz "$ORACLE_TZ" --arg kb "$ORACLE_KB" '.timezone = $tz | .locale_config.kb_layout = $kb
    | .disk_config.device_modifications[0] |= (.device = $d | .partitions[1].size.value = $m)' \
    /tmp/oracle-arch.json >/tmp/oracle-config.json
  printf '\n'; say "Installing Arch on $ORACLE_DISK (wiped: 4G /boot, the rest encrypted). No more questions: this takes 10 to 30 minutes."
  archinstall --config /tmp/oracle-config.json --creds /tmp/oracle-creds.json --silent </dev/tty && mountpoint -q /mnt \
    || die "The Arch install failed. Check the internet connection, then start the installer again. Log: /var/log/archinstall/install.log"
  rm -f /tmp/oracle-creds.json

  say "Installing Oracle (packages and settings)"
  SUDO=/mnt/etc/sudoers.d/zz-oracle-install
  trap 'rm -f "$SUDO"' EXIT
  install -m440 /dev/stdin "$SUDO" <<<"$U ALL=(ALL) NOPASSWD: ALL"
  cp "${BASH_SOURCE[0]:-}" /mnt/var/tmp/oracle-install.sh
  ORACLE_CHROOT=1 arch-chroot /mnt su "$U" -c 'bash /var/tmp/oracle-install.sh' </dev/null || die "Oracle install failed. Check the internet connection, then start the installer again. Log: scroll up, the first line starting with !!"
  rm -f "$SUDO" /mnt/var/tmp/oracle-install.sh
  ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
  for f in /var/lib/iwd/*.psk; do # Wi-Fi known here → NetworkManager
    s=${f##*/}; s=${s%.psk}; p=$(sed -n 's/^Passphrase=//p' "$f" 2>/dev/null || true)
    [[ -n $p && $s != =* ]] || continue
    printf '[connection]\nid=%s\ntype=wifi\n[wifi]\nssid=%s\n[wifi-security]\nkey-mgmt=wpa-psk\npsk=%s\n' "$s" "$s" "$p" \
      | install -Dm600 /dev/stdin "/mnt/etc/NetworkManager/system-connections/$s.nmconnection"
  done

  if grep -q tpm2-device /mnt/etc/crypttab; then
    say "Setting up automatic disk unlock (TPM): no password at boot"
    DEV=$(cryptsetup status root | awk '$1 == "device:" {print $2}')
    printf %s "$PW" | systemd-cryptenroll --unlock-key-file=/dev/stdin --tpm2-device=auto --tpm2-pcrs=7 "$DEV"
    say "RECOVERY KEY: write it down on paper now. It opens the disk if the automatic unlock ever fails. Keep it somewhere safe, off this computer:"
    printf %s "$PW" | systemd-cryptenroll --unlock-key-file=/dev/stdin --recovery-key "$DEV"
  else
    say "No TPM found: you will type the disk password at each boot (the one you just chose)."
  fi
  sync
  printf '\n'; say "Done. Oracle is installed. After the restart, log in as $U and a short welcome guide starts."
  say "Remove the USB stick, then press Enter to restart."
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

LC=/boot/EFI/arch-limine/limine.conf # archinstall's Limine: its boot line seeds limine-entry-tool (before its AUR hook runs)
if ((!DRY)) && sudo test -f "$LC" && ! sudo test -f /etc/default/limine; then
  C=$(sudo sed -n 's/^ *cmdline: //p' "$LC" | head -1)
  printf 'ESP_PATH="/boot"\nKERNEL_CMDLINE[default]+="%s"\nBOOT_ORDER="*, *fallback, Snapshots"\n' "$C" | sudo tee /etc/default/limine >/dev/null
fi
if ((!DRY)) && ! sudo test -f /etc/default/limine; then # other boot loader (Arch installed without the Oracle USB): its kernel hooks stay
  mapfile -t AUR < <(printf '%s\n' "${AUR[@]}" | grep -v '^limine-')
fi

if ((${#AUR[@]})); then
  if ! command -v yay >/dev/null; then
    say "yay (AUR helper)"
    T=$(mktemp -d)
    run git clone -q https://aur.archlinux.org/yay-bin.git "$T/yay-bin"
    if ((DRY)); then run makepkg -si --noconfirm; else (cd "$T/yay-bin" && makepkg -si --noconfirm); fi
  fi
  Y=(yay -S --needed --noconfirm "${AUR[@]}")
  if [[ -n ${ORACLE_CHROOT:-} ]]; then # arch-chroot's /proc is from another pid namespace; the GraalVM builds (limine tools) need a matching one
    run sudo unshare --pid --fork --mount-proc su "$USER" -c "${Y[*]}"
  else run "${Y[@]}"; fi
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

say "desktop config = owner's dotfiles (waybar, fuzzel, notifications, idle, lock, gtk, btop, fastfetch, git, home folders)"
while IFS= read -r f; do
  f=${f#"$SRC/config/"}; [[ $f == hypr/hyprland.lua ]] && continue
  if [[ -e $HOME/.config/$f ]]; then say "  kept your ~/.config/$f"; else run install -Dm"$([[ $f == *.sh ]] && echo 755 || echo 644)" "$SRC/config/$f" "$HOME/.config/$f"
    ((DRY)) || sed -i "s|@HOME@|$HOME|g" "$HOME/.config/$f"; fi # look stubs (include the shared look) need absolute paths
done < <(find "$SRC/config" -type f | sort)
((DRY)) || "$DIR/bin/oracle" look || true # tokens → ~/.config/oracle/look/* (bar, launcher, panels, lock, borders, GTK)
run mkdir -p "$HOME"/{Desktop,Documents,Downloads,Music,Pictures,Public,Templates,Videos} # folders named in ~/.config/user-dirs.dirs
B=$HOME/.config/gtk-3.0/bookmarks # Files (Nautilus) sidebar
if [[ -e $B ]]; then say "  kept your $B"; else run mkdir -p "${B%/*}"; ((DRY)) || printf 'file://%s/Downloads Downloads\nfile://%s/.config .config\n' "$HOME" "$HOME" >"$B"; fi

say "ghostty + tmux config"
ucfg() { # ucfg <file> <include line>: user file with include, only if missing
  if [[ -e $1 ]]; then say "  kept your $1"; else run mkdir -p "${1%/*}"; ((DRY)) || printf '%s\n# your changes below\n' "$2" >"$1"; fi
}
# ghostty loads included files after the whole file, so your changes go in a file included last
G=$HOME/.config/ghostty/config
if [[ -e $G ]]; then say "  kept your $G"; ((DRY)) || grep -qF '../oracle/ghostty' "$G" || printf 'config-file = ?../oracle/ghostty\n' >>"$G"
else run mkdir -p "${G%/*}"; ((DRY)) || printf '%s\n' "config-file = $DIR/default/ghostty/config" 'config-file = ?../oracle/ghostty' \
  '# your changes go in ~/.config/ghostty/mine (loaded last, so they win)' 'config-file = ?mine' >"$G"; fi
ucfg "$HOME/.config/tmux/tmux.conf" "source-file $DIR/default/tmux.conf"

say "zsh + tty1 autostart"
ucfg "$HOME/.zshrc" "[[ -f $DIR/default/zshrc ]] && source $DIR/default/zshrc"
LINE='[[ -f ~/.local/share/oracle/default/bash_profile ]] && . ~/.local/share/oracle/default/bash_profile'
for BP in "$HOME/.bash_profile" "$HOME/.zprofile"; do
  if [[ -f $BP ]] && grep -qF "$LINE" "$BP"; then
    say "  already in $BP"
  else
    [[ -f $BP || ! -f /etc/skel/${BP##*/} ]] || run cp "/etc/skel/${BP##*/}" "$BP"
    if ((DRY)); then printf '   would append to %s: %s\n' "$BP" "$LINE"; else printf '\n%s\n' "$LINE" >>"$BP"; fi
  fi
done
SH=$(getent passwd "$USER" | cut -d: -f7)
if [[ $SH == */zsh ]]; then say "  login shell: zsh"; elif [[ -x /usr/bin/zsh ]]; then run sudo chsh -s /usr/bin/zsh "$USER"; fi

say "oracle command"
BIN=$HOME/.local/bin/oracle
if [[ $(readlink "$BIN") != "$DIR/bin/oracle" ]]; then
  if [[ -e $BIN ]]; then run mkdir -p "$BACKUP"; run mv "$BIN" "$BACKUP/"; fi
  run mkdir -p "${BIN%/*}"; run ln -s "$DIR/bin/oracle" "$BIN"
fi
say "AI tools: Claude Code (updates itself) + OpenCode (pacman, updates with oracle update). Optional: a failure doesn't stop the install"
if [[ -x $HOME/.local/bin/claude ]]; then say "  Claude Code: already installed"
elif ((DRY)); then echo "   would install Claude Code (claude.ai/install.sh)"
else curl -fsSL https://claude.ai/install.sh | bash || say "  Claude Code failed, later: curl -fsSL https://claude.ai/install.sh | bash"; fi
if command -v opencode >/dev/null; then say "  OpenCode: already installed"
else run sudo pacman -S --needed --noconfirm opencode || say "  OpenCode failed, later: sudo pacman -S opencode"; fi
M=$HOME/.local/state/oracle/migrations
run mkdir -p "$M"
for m in "$SRC"/migrations/*.sh; do [[ ! -f $m ]] || run touch "$M/${m##*/}"; done

N=(); [[ -d /run/systemd/system && -z ${ORACLE_CHROOT:-} ]] && N=(--now) # start services now (not in the USB installer's chroot)

say "rollback for updates (btrfs snapshots before every update: oracle rollback)"
if [[ $(findmnt -no FSTYPE /) == btrfs ]] && ((!DRY)); then
  [[ -e /var/lib/docker ]] || sudo btrfs -q subvolume create /var/lib/docker # docker images stay out of snapshots
  if [[ ! -f /etc/snapper/configs/root ]]; then
    sudo snapper --no-dbus -c root create-config /
    sudo snapper --no-dbus -c root set-config NUMBER_LIMIT=20 NUMBER_LIMIT_IMPORTANT=5 TIMELINE_CREATE=no
  fi
  run sudo systemctl enable "${N[@]}" snapper-cleanup.timer
else
  say "  skip: / is not btrfs, or dry-run"
fi

say "boot menu: Limine, with snapshots to start an older system. Hidden: tap M at power-on to open it. Silent boot"
if ((!DRY)) && command -v limine-entry-tool >/dev/null && sudo test -f /etc/default/limine; then
  run sudo systemctl enable "${N[@]}" limine-snapper-sync.service
  Q=/etc/limine-entry-tool.d/oracle-quiet.conf # no boot text (failures and the disk password prompt still show); new kernels + snapshots keep it
  QL='KERNEL_CMDLINE[default]+="quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0"'
  UP=0; [[ $(cat "$Q" 2>/dev/null) == "$QL" ]] || { echo "$QL" | sudo install -Dm644 /dev/stdin "$Q"; UP=1; }
  if sudo test -d /boot/EFI/arch-limine; then # archinstall's own Limine copy → replaced by limine-entry-tool's (/boot/limine.conf)
    sudo limine-install || sudo limine-install --skip-uefi --fallback || true
    sudo limine-update && sudo test -s /boot/limine.conf || die "Limine setup failed"
    sudo rm -rf /boot/EFI/arch-limine /etc/pacman.d/hooks/99-limine.hook /boot/vmlinuz-linux /boot/initramfs-linux.img /boot/initramfs-linux-fallback.img
    for b in $(sudo efibootmgr | sed -n 's/^Boot\([0-9A-F]\{4\}\)\* Arch Linux Limine Bootloader.*/\1/p'); do sudo efibootmgr -q -b "$b" -B; done
  elif ((UP)); then sudo limine-update || say "  limine-update failed: boot text stays until the next kernel update"; fi
  # global options on top of /boot/limine.conf (limine-entry-tool keeps them). editor off: TPM unlocks the disk, so no editing the boot line.
  # quiet + timeout 1: boots at once with nothing on screen; a key pressed in that second opens the menu (Limine CONFIG.md: quiet)
  CH=0
  for o in 'editor_enabled: no' 'timeout: 1' 'quiet: yes' 'firmware_logo: yes' 'interface_branding: Oracle' 'interface_branding_colour: c8c8c8' 'interface_help_colour: 8a8a8a' \
    'term_palette: 000000;a05a5a;8a8a8a;aaaaaa;8a8a8a;aaaaaa;8a8a8a;aaaaaa' 'term_palette_bright: 555555;c07070;c8c8c8;e0e0e0;c8c8c8;e0e0e0;c8c8c8;ffffff'; do
    k=${o%%:*}
    if sudo grep -q "^$k:" /boot/limine.conf; then sudo grep -qx "$o" /boot/limine.conf || { sudo sed -i "s/^$k:.*/$o/" /boot/limine.conf; CH=1; }
    else sudo sed -i "1i $o" /boot/limine.conf; CH=1; fi
  done
  SBH=/usr/local/bin/oracle-secureboot # Secure Boot on (oracle secureboot): a changed limine.conf must be locked into Limine again, or it won't boot
  if sudo test -x "$SBH"; then sudo cmp -s "$SRC/system/oracle-secureboot" "$SBH" || sudo install -m755 "$SRC/system/oracle-secureboot" "$SBH"; fi
  if ((CH)) && sudo grep -q '^ENABLE_ENROLL_LIMINE_CONFIG=yes' /etc/default/limine; then sudo limine-enroll-config >/dev/null && sudo "$SBH" hook; fi
else
  say "  skip: not installed with Limine, or dry-run"
fi

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

say "firewall: nothing gets in except Tailscale. LLMNR off"
run sudo bash "$SRC/system/oracle-firewall" "${N[@]}"

say "bluetooth"
run sudo systemctl enable bluetooth.service

say "desktop on the AMD chip (if this machine has one at 04:00.0, like the G14)"
R=/etc/udev/rules.d/61-oracle-amd-igpu.rules
if ((!DRY)) && [[ ! -f $R ]]; then echo 'SUBSYSTEM=="drm", KERNEL=="card[0-9]*", KERNELS=="0000:04:00.0", SYMLINK+="dri/amd-igpu"' | sudo tee "$R" >/dev/null; fi

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
((DRY)) || { sudo chgrp wheel /etc/oracle/battery-limit; sudo chmod 664 /etc/oracle/battery-limit; } # settings can change it without a password
if ((!DRY)) && [[ ! -f /etc/systemd/system/oracle-battery.path ]]; then
  printf '[Unit]\nDescription=Oracle: apply battery limit when it changes\n[Path]\nPathChanged=/etc/oracle/battery-limit\n[Install]\nWantedBy=multi-user.target\n' |
    sudo tee /etc/systemd/system/oracle-battery.path >/dev/null
fi
run sudo systemctl enable "${N[@]}" oracle-battery.service oracle-battery.path

say "lid closed → screen off, keeps running"
if ((!DRY)) && ! cmp -s "$SRC/system/oracle-lid" /usr/local/bin/oracle-lid; then sudo install -Dm755 "$SRC/system/oracle-lid" /usr/local/bin/oracle-lid; sudo systemctl try-restart oracle-lid.service 2>/dev/null || true; fi
if ((!DRY)) && [[ ! -f /etc/systemd/system/oracle-lid.service ]]; then
  printf '[Unit]\nDescription=Oracle: backlight off while the lid is closed\n[Service]\nExecStart=/usr/local/bin/oracle-lid\nRestart=always\n[Install]\nWantedBy=multi-user.target\n' |
    sudo tee /etc/systemd/system/oracle-lid.service >/dev/null
fi
run sudo systemctl enable "${N[@]}" oracle-lid.service

say "login: Oracle screen on tty1 (your name shown, password asked; no autologin). tty2 (Ctrl+Alt+F2) = plain login"
if ((!DRY)); then
  cmp -s "$SRC/system/oracle-login" /usr/local/bin/oracle-login || sudo install -Dm755 "$SRC/system/oracle-login" /usr/local/bin/oracle-login
  G=/etc/systemd/system/getty@tty1.service.d/oracle-login.conf
  GL=$(printf '[Service]\nExecStart=\nExecStart=-/usr/bin/agetty --skip-login --login-program /usr/local/bin/oracle-login --login-options %s --noreset --noclear - ${TERM}' "$USER")
  if [[ $(cat "$G" 2>/dev/null) != "$GL" ]]; then
    echo "$GL" | sudo install -Dm644 /dev/stdin "$G"
    [[ ${#N[@]} == 0 ]] || sudo systemctl daemon-reload # takes effect at the next login screen; never restart tty1 (your session may be on it)
  fi
  C=/etc/issue.d/oracle-cursor.issue # silent boot hides the console cursor; plain logins show it again
  [[ -f $C ]] || printf '\e[?25h' | sudo install -Dm644 /dev/stdin "$C"
fi

say "battery: notices at 20% and 10%, clean shutdown at 4% (the server's data stays safe). Never sleeps"
if ((!DRY)) && ! cmp -s "$SRC/system/oracle-power" /usr/local/bin/oracle-power; then sudo install -Dm755 "$SRC/system/oracle-power" /usr/local/bin/oracle-power; sudo systemctl try-restart oracle-power.service 2>/dev/null || true; fi
PU=$'[Unit]\nDescription=Oracle: battery notices, clean shutdown at 4%\n[Service]\nExecStart=/usr/local/bin/oracle-power\nRestart=on-failure\n[Install]\nWantedBy=multi-user.target'
if ((!DRY)) && [[ $(cat /etc/systemd/system/oracle-power.service 2>/dev/null) != "$PU" ]]; then echo "$PU" | sudo tee /etc/systemd/system/oracle-power.service >/dev/null; [[ -z ${N[*]} ]] || sudo systemctl daemon-reload; fi
[[ $(systemctl is-enabled oracle-power.service 2>/dev/null) == masked ]] && say "  kept off (masked)" || run sudo systemctl enable "${N[@]}" oracle-power.service

say "alerts in plain words (full disk, failed service, app crash, Wi-Fi sign-in, server app down) + a quiet weekly update check"
WS=$'[Unit]\nDescription=Oracle: plain-word alerts and the weekly update check\n[Service]\nType=oneshot\nExecStart=%h/.local/share/oracle/bin/oracle-watch\nKillMode=process\nNice=10'
WT=$'[Unit]\nDescription=Oracle: look for problems every 5 minutes\n[Timer]\nOnStartupSec=5min\nOnUnitActiveSec=5min\nAccuracySec=1min\n[Install]\nWantedBy=timers.target'
for u in service:"$WS" timer:"$WT"; do
  f=/etc/systemd/user/oracle-watch.${u%%:*}
  ((DRY)) || [[ $(cat "$f" 2>/dev/null) == "${u#*:}" ]] || echo "${u#*:}" | sudo tee "$f" >/dev/null
done
run sudo systemctl --global enable oracle-watch.timer
((DRY)) || [[ -z ${N[*]} ]] || { systemctl --user daemon-reload && systemctl --user start oracle-watch.timer; } 2>/dev/null || true

say "clock set automatically (network time)"
if systemctl is-enabled -q chronyd ntpd 2>/dev/null; then say "  kept your chrony/ntpd"; else run sudo systemctl enable "${N[@]}" systemd-timesyncd.service; fi

say "Setting up automatic disk unlock (TPM): no password at boot"
L=/boot/loader/loader.conf
if ((!DRY)) && sudo test -f "$L" && ! sudo grep -q '^editor' "$L"; then run sudo sh -c "echo 'editor no' >> $L"; fi
MAP=$(findmnt -nvo SOURCE /)
DEV=$( ((DRY)) || sudo cryptsetup status "$MAP" 2>/dev/null | awk '$1 == "device:" {print $2}' || true)
HK='HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)'
[[ -f /usr/lib/initcpio/install/sd-btrfs-overlayfs ]] && HK=${HK/filesystems/filesystems sd-btrfs-overlayfs} # boot-menu snapshots start writable
HF=/etc/mkinitcpio.conf.d/oracle-tpm.conf
initramfs() { if command -v limine-mkinitcpio >/dev/null; then sudo limine-mkinitcpio; else sudo /usr/bin/mkinitcpio -P; fi; }
if [[ -z $DEV || ! -e /dev/tpmrm0 ]]; then
  say "  skip: root not on LUKS, no TPM, or dry-run"
elif [[ $(sudo systemd-cryptenroll "$DEV") == *tpm2* ]]; then
  say "  already enrolled"
  [[ $(cat "$HF" 2>/dev/null) == "$HK" ]] || { echo "$HK" | sudo tee "$HF" >/dev/null; initramfs; }
else
  UUID=$(sudo cryptsetup luksUUID "$DEV")
  sudo grep -q "$UUID" /etc/crypttab || echo "${MAP##*/} UUID=$UUID none tpm2-device=auto,x-initrd.attach" | sudo tee -a /etc/crypttab >/dev/null
  echo "$HK" | sudo tee "$HF" >/dev/null
  initramfs
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

say "done. Reboot, type your password on the Oracle screen → Shell mode (g = desktop). Later: oracle update"
((WIFI)) && say "Wi-Fi: after reboot run nmtui once to reconnect."
exit 0
