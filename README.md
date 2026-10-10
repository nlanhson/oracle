# Oracle

AI-only context. Owner never reads repo. Keep terse.
ascii.rest (MIT, github.com/bas3line/ascii) = visual recipe only. Web code, cannot run in terminal; redraw in our own TUI, credit author.

## Hard rules
- Owner = UI/UX designer, not engineer. Replies: short, plain words, TL;DR first. Ideas ok, one line max. No option menus for small stuff.
- Repo for AI only. Fewest files. Minimal comments. No human-style docs. Many files = loss.
- Bare minimum first. Grow one small step at a time. Never build whole distro at once.
- Small choices: decide, note below. Ask owner only big/irreversible.
- No destructive cmd (partition, format, encrypt, delete) without owner yes.
- Done = evidence (test output).
- Light/fast like pure Arch. Every package justified.
- Name "Oracle", never "Oracle OS". Batman's Oracle, machine = Batcomputer.

## What
Arch respin. Fresh Arch (any config) → run installer → Oracle.
Never run installer for real on current machine (CachyOS). Test: `archlinux` docker container (fast) + `test/vm.sh` (full: ISO → archinstall → installer → reboot, QEMU/KVM inside docker, swtpm).

Install: `curl -fsSL https://raw.githubusercontent.com/nlanhson/oracle/main/install.sh | bash`
- Same line twice. 1) Booted Arch ISO (UEFI; Wi-Fi: `iwctl station wlan0 connect <ssid>`): asks ONE password (user son + root + LUKS), opens archinstall menu prefilled from `archinstall.json` → owner checks, presses Install. Reboot, type disk password once, log in as son. 2) Run again → Oracle + TPM unlock (asks disk password once, prints recovery key to write down). Reboot → no password at boot.
- Why install.sh writes creds: archinstall drops `disk_encryption` from a config with no password (DiskEncryption.parse_arg), so plain `--config-url` loses LUKS. Creds only in ISO RAM `/tmp`.
- `archinstall.json`: G14 only. Wipes /dev/nvme0n1; sizes hardcoded for 512110190592 B disk (EFI 1G /boot, rest LUKS2 btrfs @ @home @log @pkg, zstd). Other disk → recompute root size (archinstall rejects too-large). systemd-boot (no UKI), linux, pipewire, NetworkManager, minimal profile, zram, Asia/Ho_Chi_Minh, en_US, us.
- TPM step: archinstall uses busybox `encrypt` hook (sd-encrypt only with FIDO2). install.sh adds `/etc/mkinitcpio.conf.d/oracle-tpm.conf` (systemd + sd-encrypt hooks), crypttab line `tpm2-device=auto,x-initrd.attach`, recovery key, `systemd-cryptenroll --tpm2-pcrs=7`. Skips if no LUKS root, no /dev/tpmrm0, or tpm2 token exists. Old `cryptdevice=` cmdline arg left, ignored. TPM fail → password/recovery key prompt at boot (needs keyboard).
- Test: `test/vm.sh` (docker + /dev/kvm only, ~15-20 min): real ISO + QEMU NVMe disk of G14 size + swtpm + OVMF, drives the serial console, serves the working tree as ORACLE_REPO/ORACLE_RAW. `test/vm.sh oracle` = reuse installed Arch. Files: `$VM_DIR` (default ~/.cache/oracle-vm, ~7G).

## Structure (copied from Omarchy v3 model, not v4)
- Install = clone repo to `~/.local/share/oracle`, run `install.sh` (linear, re-runnable: `--needed`, mkdir -p, copy-if-missing). Clone stays = update source.
- Defaults vs user: `default/` lives in clone, loaded live (hyprland.lua extends package.path → `require` default). User `~/.config` files load last, copied only if missing, never overwritten by update. Keybinds: default data file + user override data file.
- `oracle update` = git pull + `sudo pacman -Syu` + `yay -Sua` + migrations + reboot hint if kernel changed. One `oracle` script with `case`, not many bin scripts.
- Growth = `migrations/<unix-ts>.sh`, tiny + idempotent, markers in `~/.local/state/oracle/migrations/`. Fresh install marks all done.
- System config only as drop-ins named `oracle-*` (logind.conf.d, sysctl.d, udev rules.d, systemd units). Never edit vendor files.
- Avoid: ISO/packages model, hundreds of scripts, themes/templates before needed, auto-overwrite of ~/.config.

## v1 (built 2026-10-11, VM-tested via test/vm.sh; not yet on real hardware)
Hyprland + ghostty + Brave Origin (AUR `brave-origin-bin` via yay). Hyprland autostart on tty1. Keybinds from owner's dotfiles `.config/hypr/modules/binds.lua` (Lua config). Plus xdg-desktop-portal-hyprland, hyprpolkitagent. Must work with ANY archinstall choice: installer adds networkmanager + systemd-resolved (+ resolv.conf stub, disables networkd/iwd/dhcpcd, effective after reboot) and pipewire (replaces pulseaudio). No extra fonts.

## Later (one at a time, owner picks when)
- Shell mode (default after login): cage + foot + tmux. Home dashboard + coding. GUI mode = Hyprland on demand. Separate clipboards accepted.
- Dashboard (Shell home): ascii.rest style. Bars like `Volume [=====-----] 50%`. Rows: cpu/ram/disk/temp/battery/volume/brightness, server apps up/down + ports, tailscale, wifi, clock. Bottom: bracket links `[code] [files] [server] [gui]`. Parts (owner picks, 2026-10-11):
  - CPU/GPU: sparklines https://ascii.rest/sparkline/
  - Clock + calendar https://ascii.rest/calendar/ . 12h with AM/PM, NEVER 24h.
  - Embedded terminal pane, 2 states inactive/active https://ascii.rest/terminal/ (likely tmux pane).
  - Claude Code usage heatmap (like `/usage` stats), refresh every minute https://ascii.rest/heatmap/ . Data: local logs `~/.claude/projects/**/*.jsonl` (token usage per message), no network. Plan-limit % later if a local source exists.
  - File navigator https://ascii.rest/file-tree/ (custom or themed yazi; decide when built).
  - Settings screen https://ascii.rest/form-controls/ : brightness, volume, wallpaper, theme, etc. + keybind editor (so keep binds in a simple data file the settings screen can edit, not hand-edited Lua).
- Look: near-black bg, grey/white text, electric cyan accent, muted dark red warn. IBM Plex Mono. ascii.rest style, bracket links `[gui]`.
- Vietnamese: fcitx5 + fcitx5-bamboo, GUI only. Brave flags in `~/.config/brave-origin-flags.conf`: `--ozone-platform=wayland --enable-wayland-ime --wayland-text-input-version=3`.
- Server, moved unchanged: github.com/nlanhson/homeserver. Docker + Dockge (`~/docker/<app>`, `~/dockge`), Immich :2283 (>=3.2.2), Dockge :5001, vpn stack. Tailscale: restore state to keep 100.108.66.46. Net: NetworkManager + systemd-resolved, `/etc/resolv.conf` → `../run/systemd/resolve/stub-resolv.conf` (MagicDNS). logind ignore lid + IdleAction. Screen off on lid (cage: needs watcher). Docker ports bypass ufw.
- Hardware (ASUS G14 GA401QC, AMD iGPU + RTX 3050): `linux` + `nvidia-open`. Pin compositor to iGPU (`/etc/udev/rules.d/61-amd-igpu.rules`: `SUBSYSTEM=="drm", KERNEL=="card[0-9]*", KERNELS=="0000:04:00.0", SYMLINK+="dri/amd-igpu"`; then `AQ_DRM_DEVICES`/`WLR_DRM_DEVICES=/dev/dri/amd-igpu`), dGPU sleeps D3cold. mkinitcpio `MODULES=(amdgpu)`. Battery cap 80 via sysfs `charge_control_end_threshold` + oneshot unit (resets each boot). power-profiles-daemon balanced. zram-generator (ram, zstd), swappiness 150.
- Disk: LUKS2 + TPM auto-unlock + btrfs done (see Install). GAP: PCR7-only with Secure Boot OFF → attacker with a live USB can unseal the key. Fix later: Secure Boot own keys (sbctl, owner puts firmware in Setup Mode) + UKI, keep PCR7. Meanwhile systemd-boot `editor no`. Must boot unattended after power cut. No autologin. SSH key-only.
- Default apps when needed: yazi, micro, btop, nmtui, wiremix, wl-clipboard, bash + zsh.
