# Oracle: context for AI agents

Terse context for coding agents. Humans read README.md + docs/ (write those carefully, plain English, like a real distro). Keep this file terse.
ascii.rest (MIT, github.com/bas3line/ascii) = visual recipe only. Web code, cannot run in terminal; redraw in our own TUI, credit author.

## Working with the owner
- Owner talks to ONE main Claude session = project manager. It may delegate to helper agents/sessions; helpers report to it, never to the owner.
- Owner is away often and low on usage sometimes: keep replies short, batch work, report outcomes with evidence.

## Hard rules
- Owner = UI/UX designer, not engineer. Replies: short, plain words, TL;DR first. Ideas ok, one line max. No option menus for small stuff.
- Few files, minimal code comments. Human docs only in README.md / docs/. Modules where they help (owner's suggestion, not mandatory).
- Commits: author nlanhson <nlanhson@gmail.com>. NO AI attribution (no Co-Authored-By/Claude trailers).
- Bare minimum first. Grow one small step at a time. Never build whole distro at once.
- Small choices: decide, note below. Ask owner only big/irreversible.
- No destructive cmd (partition, format, encrypt, delete) without owner yes.
- Done = evidence (test output).
- Light/fast like pure Arch. Every package justified.
- Name "Oracle", never "Oracle OS". Batman's Oracle, machine = Batcomputer.

## What
Arch respin. Fresh Arch (any config) → run installer → Oracle.
Never run installer for real on current machine (CachyOS). Test: `archlinux` docker container (fast) + `test/vm.sh` (full: ISO → one-pass install → reboot, QEMU/KVM inside docker, swtpm).

Download: Oracle ISO from https://github.com/nlanhson/oracle/releases/latest (`oracle-*.iso` + `.sha256`), flash with balenaEtcher/caligula, boot (UEFI).
Install (one pass, no reboot in between): boot the Oracle ISO (installer autostarts on tty1) or a stock Arch ISO + `curl -fsSL https://raw.githubusercontent.com/nlanhson/oracle/main/install.sh | bash`.
- Screens: no internet → Wi-Fi list (iwctl), type name + password, retry. Disk list (`lsblk`, USB itself hidden) → type disk name = wipe confirmed (`ORACLE_DISK=/dev/x` skips). ONE password (son + root + LUKS), twice. Then unattended: archinstall `--silent` → Oracle install.sh in `arch-chroot /mnt su son` (temp sudoers `zz-oracle-install` NOPASSWD (sorts after archinstall's `00_son`; last match wins), removed after) → TPM enroll from ISO → RECOVERY KEY printed last → Enter = reboot. Boot: no password. tty1 login son → Shell/dashboard.
- ISO = launcher only: install.sh first fetches newest install.sh + archinstall.json from GitHub (RAW); USB copies only if fetch fails (says so). Repo clone + packages always latest. Rebuild ISO rarely.
- Chroot: `ORACLE_CHROOT=1` (arch-chroot bind-mounts host /run, so /run/archiso is visible: env var guards recursion). In chroot: TPM step writes crypttab/hooks/mkinitcpio only, enroll done outside; resolv.conf stub symlink written to /mnt after chroot; docker can't start → server.sh writes `oracle-firstboot.service` (User=son, `server.sh start`, Restart=on-failure until online, then disables itself). ISO Wi-Fi (`/var/lib/iwd/*.psk`) → NM keyfile.
- Why install.sh writes creds: archinstall drops `disk_encryption` from a config with no password (DiskEncryption.parse_arg). Creds only in ISO RAM `/tmp`, deleted after archinstall.
- `archinstall.json`: device + root size jq-edited at runtime (root MiB = disk/MiB − 1026: 1 MiB gap, 1 GiB EFI /boot, 1 MiB GPT backup; min 32 GB). Rest LUKS2 btrfs @ @home @log @pkg, zstd. systemd-boot (no UKI), linux, pipewire, NetworkManager, minimal profile, zram, Asia/Ho_Chi_Minh, en_US, us. G14 tweaks later behind DMI check.
- TPM step: archinstall uses busybox `encrypt` hook. install.sh adds `/etc/mkinitcpio.conf.d/oracle-tpm.conf` (systemd + sd-encrypt), crypttab `tpm2-device=auto,x-initrd.attach`, recovery key, `systemd-cryptenroll --tpm2-pcrs=7` (PCR7 same on ISO and installed boot, Secure Boot off). Already-installed Arch (no ISO): same curl line, asks disk password, idempotent. TPM fail → password/recovery key prompt at boot (needs keyboard).
- ISO: `iso/build.sh <outdir>` (docker --privileged, releng copied at build: name/label Oracle, jq, `/root/oracle/{install.sh,archinstall.json}`, one `.zlogin` line). CI: `.github/workflows/iso.yml` tag `v*` → Release assets; manual run → workflow artifact.
- Test: `test/vm.sh iso` (our ISO, 64G NVMe) / `test/vm.sh` (stock ISO + curl, G14-size NVMe) / `test/vm.sh oracle` (reuse installed disk). Docker + /dev/kvm only, ~20-30 min: QEMU + OVMF + swtpm, serial console, serves working tree as ORACLE_REPO/ORACLE_RAW. Files: `$VM_DIR` (default ~/.cache/oracle-vm, ~10G; use /var/tmp/oracle-vm here).

## Structure (copied from Omarchy v3 model, not v4)
- Install = clone repo to `~/.local/share/oracle`, run `install.sh` (linear, re-runnable: `--needed`, mkdir -p, copy-if-missing). Clone stays = update source.
- Defaults vs user: `default/` lives in clone, loaded live (hyprland.lua extends package.path → `require` default). User `~/.config` files load last, copied only if missing, never overwritten by update. Hyprland defaults modular (owner style): default/hypr/hyprland.lua loads env/look/input/autostart.lua + binds.lua (data) via keys.lua; user ~/.config/hypr/hyprland.lua overrides `O.binds[...]` before `O.apply()`.
- `bin/oracle` (linked to ~/.local/bin, PATH via default/bash_profile): `oracle update` = git pull --ff-only → pending `migrations/*.sh` (marker per file) → re-run install.sh (idempotent = applies new pkgs/configs, pacman -Syu) → `yay -Sua` → reboot hint. `oracle backup <dir>` → server.sh backup. `oracle restore <dir>` → install.sh --restore. User manual: docs/manual/*.md (keep in sync when features change). New features go in install.sh; migrations only for one-off changes (removals/renames). Container-tested.
- Growth = `migrations/<unix-ts>.sh`, tiny + idempotent, markers in `~/.local/state/oracle/migrations/`. Fresh install marks all done.
- System config only as drop-ins named `oracle-*` (logind.conf.d, sysctl.d, udev rules.d, systemd units). Never edit vendor files.
- Avoid: ISO/packages model, hundreds of scripts, themes/templates before needed, auto-overwrite of ~/.config.

## v1 (built 2026-10-11, VM-tested via test/vm.sh; not yet on real hardware)
Hyprland (owner's config, see Desktop) + ghostty + Brave Origin (AUR `brave-origin-bin` via yay). Plus xdg-desktop-portal-hyprland. Must work with ANY archinstall choice: installer adds networkmanager + systemd-resolved (+ resolv.conf stub, disables networkd/iwd/dhcpcd, effective after reboot) and pipewire (replaces pulseaudio). Fonts: noto-fonts + emoji (Brave Origin, Vietnamese, emoji; ghostty has its own).

## Server (built 2026-10-11, container-tested)
From github.com/nlanhson/homeserver, unchanged stacks. `server/server.sh`, called by install.sh.
- Setup: docker + tailscaled enabled (`--now`), user → docker group, `/etc/systemd/logind.conf.d/oracle-server.conf` (lid ignore). Stacks copy-if-missing → `~/dockge`, `~/docker/{immich,vpn}` (`${HOME}` expanded). Start only if secrets exist (immich `.env`; vpn `.env` + tailscale state or `ts.env`). Immich pinned `v3` (>=3.2.2).
- Restore: `install.sh --restore <backup|stick root>`. .env files, dockge data, tailscale state (host → keeps 100.108.66.46; vpn-exit), photos (sha256 checked), newest dump → postgres db → rename to immich (lesson 1), `.immich` markers (lesson 2), asset count = dump. Refuses if `~/docker/immich/postgres` not empty. Markers `~/.local/state/oracle/done/`.
- Backup: `server.sh backup <dir>` (same layout, top-up safe): fresh pg_dump (count checked) → sha256 → copy → drop caches → verify from disk. Tailscale tarballs need sudo. Layout: `immich/library/{upload,backups}`, `upload.sha256`, `configs/{docker/immich,docker/vpn,dockge}`, `configs/tailscale-{host,vpn}.tar.gz`.
- USB stick (SanDisk 28.6G exFAT) `oracle-migration-2026-10-10/` = this layout minus tailscale tarballs. Move day: owner runs `server.sh backup <that folder>` on CachyOS (top-up + tailscale), then wipe.

## Shell mode + look + dashboard (built, VM-tested)
tty1 login → `oracle session` loop: Shell = `cage -s -- ghostty -e oracle attach`. tmux session `oracle`, workspaces 1-4 always exist (`oracle tabs`, re-created by tmux hook `window-unlinked`): 1 = `oracle home` dashboard, 2-4 = terminals. Bar at TOP: `ORACLE` left, workspaces center (inactive = number, active = `[2:terminal]`, auto-rename shell → "terminal" else program name), right = `5:15 PM · Sunday, 11 October`. Alt+1..4 (ghostty alt+digit unbound). Mouse works (tmux mouse on).
Dashboard = bin/oracle-home: two columns. Left ~28% (min 38 cols): clock (3x5 pixel digits, 2 cells/pixel, lit █ unlit ░, 32 wide, no am/pm/date under it) + calendar (own, 32 wide, today `[11]`). Right: `── title ───` sections: system (cpu/gpu/memory sparklines, disk+battery `━━━───`), controls (volume/brightness `[====----]`), claude (heatmap `· ░ ▒ ▓ █`, 12am/6am/12pm/6pm), server, footer `[g]ui [f]iles [s]ettings [u]pdate`. Widgets default/home/<name>.sh `w_<name>`; oracle-home places them in the same shell (state kept), frame wrapped in synchronized output (?2026). 2s refresh. 12h ALWAYS.
- `oracle files` (bin/oracle-files): ascii.rest file-tree, folders expand in place, `──>` = selected, `.` hidden. File → text: read (micro -readonly) / edit (micro) / edit as admin (sudoedit, SUDO_EDITOR=micro); other: `oracle open` = write ~/.local/state/oracle/open + `oracle gui`; Hyprland start runs `oracle pending` → xdg-open. Inside Hyprland `oracle open` = xdg-open directly.
- `oracle settings` (bin/oracle-settings): ascii.rest form-controls box (`>` focus, sliders `━━█──`, toggles `▕██░░░░▏`, selects `[ x v ]`, buttons): brightness, volume, mute, battery limit, wifi on/off + network picker (nmcli), bluetooth on/off + devices (bluetoothctl scan/pair/trust/connect), about (user, oracle git version, kernel, uptime, memory, disk), update / restart / shutdown (y confirm). Battery file root:wheel 664 + `oracle-battery.path` → no password.
- TUI helpers in default/home/theme.sh: `key` (KEY=up/down/…), `box` (LINES[] in frame at BY;BX, BW wide), rep, num.
Look = default/ghostty/config + default/tmux.conf (user files include them), app default font. `oracle gui` → Hyprland; `oracle shell` / Super+M → back. Mode file `~/.local/state/oracle/mode`.
Screenshots: `test/shot.sh out.png [secs] [keys…]` (tmux in archlinux container, pyte → PNG, ~1 min, e.g. keys `s` settings, `f` files, `'\x1b2'` Alt+2). VM: `test/vm.sh oracle` → $VM_DIR/shell.png, gui.png.

## Desktop (GUI mode) = owner's own Hyprland config (2026-10-11, "all of it")
default/hypr/config/*.lua copied from owner's CachyOS ~/.config/hypr/config (CachyOS layout: variables, binds with digitCode, windowrules, Cachy colors, scale 1.67). Changes: no uwsm prefix, no xhost/rog-control-center, AQ_DRM_DEVICES only if /dev/dri/amd-igpu exists (udev rule 61-oracle-amd-igpu.rules), Super+M = oracle shell, lid.lua dropped (oracle-lid does all modes). Shell = Noctalia (official repo `noctalia`, v5 native): bar, launcher, control center, lock, notifications, clipboard, polkit agent. ~/.config/noctalia/config.toml + ~/.config/hypr/noctalia.lua (theme) + xdph.conf copied if missing from config/ (clock switched to 12h). Apps: nautilus, gnome-text-editor, gnome-calculator, btop, hyprpicker, swash (AUR, screenshot annotate), noto-fonts(+emoji), wl-clipboard, xdg-utils, bluez. User file ~/.config/hypr/hyprland.lua = dofile default, own lines after (they win).

## Later (one at a time, owner picks when)
- Oracle ISO: built (see Install). Left: offline pkg cache on ISO, `restore` from stick in firstboot, Secure Boot/UKI.

- Dashboard (Shell home): ascii.rest style. Bars like `Volume [=====-----] 50%`. Rows: cpu/ram/disk/temp/battery/volume/brightness, server apps up/down + ports, tailscale, wifi, clock. Bottom: bracket links `[code] [files] [server] [gui]`. Parts (owner picks, 2026-10-11):
  - CPU/GPU: sparklines https://ascii.rest/sparkline/
  - Clock + calendar https://ascii.rest/calendar/ . 12h with AM/PM, NEVER 24h.
  - Embedded terminal pane, 2 states inactive/active https://ascii.rest/terminal/ (likely tmux pane).
  - Claude Code usage heatmap (like `/usage` stats), refresh every minute https://ascii.rest/heatmap/ . Data: local logs `~/.claude/projects/**/*.jsonl` (token usage per message), no network. Plan-limit % later if a local source exists.
  - File navigator https://ascii.rest/file-tree/ (custom or themed yazi; decide when built).
  - Settings screen https://ascii.rest/form-controls/ : brightness, volume, wallpaper, theme, etc. + keybind editor (so keep binds in a simple data file the settings screen can edit, not hand-edited Lua).
- Look: near-black bg, grey/white text, electric cyan accent, muted dark red warn. IBM Plex Mono. ascii.rest style, bracket links `[gui]`.
- Vietnamese: fcitx5 + fcitx5-bamboo, GUI only. Brave flags in `~/.config/brave-origin-flags.conf`: `--ozone-platform=wayland --enable-wayland-ime --wayland-text-input-version=3`.
- Server: built (see Server section). Left: screen off on lid (cage: needs watcher). Docker ports bypass ufw.
- Hardware (ASUS G14 GA401QC, AMD iGPU + RTX 3050): `linux` + `nvidia-open`. Pin compositor to iGPU (`/etc/udev/rules.d/61-amd-igpu.rules`: `SUBSYSTEM=="drm", KERNEL=="card[0-9]*", KERNELS=="0000:04:00.0", SYMLINK+="dri/amd-igpu"`; then `AQ_DRM_DEVICES`/`WLR_DRM_DEVICES=/dev/dri/amd-igpu`), dGPU sleeps D3cold. mkinitcpio `MODULES=(amdgpu)`. Battery cap 80 via sysfs `charge_control_end_threshold` + oneshot unit (resets each boot). power-profiles-daemon balanced. zram-generator (ram, zstd), swappiness 150.
- Disk: LUKS2 + TPM auto-unlock + btrfs done (see Install). GAP: PCR7-only with Secure Boot OFF → attacker with a live USB can unseal the key. Fix later: Secure Boot own keys (sbctl, owner puts firmware in Setup Mode) + UKI, keep PCR7. Meanwhile systemd-boot `editor no`. Must boot unattended after power cut. No autologin. SSH key-only.
- Default apps when needed: yazi, micro, btop, nmtui, wiremix, wl-clipboard, bash + zsh.

## Status (2026-10-11)
Built + VM-tested (`test/vm.sh iso` 16/16): ISO one-pass install (Wi-Fi, disk, user/tz/kb, one password, LUKS2+TPM), Shell mode + dashboard, GUI (Hyprland, Ghostty, Brave Origin), server (docker, Dockge, Immich, Tailscale, vpn) with `oracle backup/restore`, `oracle update` + migrations, MIT license, human README + docs/manual. Not yet on real hardware. ISO not yet published (needs a `v*` tag → GitHub Actions).

## Before move day (do these first, in order)
Owner 2026-10-11: ONE Oracle, tailored to owner only, not published anywhere. Public version = later (then: archinstall-style choices, encryption optional). Power saving not important: no nvidia-open/power-profiles. AMD iGPU only (GPU switching maybe later). Browser = Brave Origin (never say plain "Brave"). Vietnamese + Claude Code preinstall: later.
Done: battery limit (`/etc/oracle/battery-limit`, default 50, `oracle-battery.service` writes sysfs each boot, `oracle battery <20-100>`, dashboard shows limit). Settings screen will edit it later.
Done: lid closed → backlight off, keeps running (system/oracle-lid → /usr/local/bin, root `oracle-lid.service`, polls /proc/acpi/button/lid every 2s, saves/restores /sys/class/backlight/*/brightness; logind ignores lid via server.sh). G14 today: amdgpu_bl1.
1. Keep building (owner tweaks a lot). Repo stays PUBLIC while building. When done: owner plugs USB, copy, THEN flip private (needs: ISO carries whole repo, `gh auth login` once for `oracle update`).
2. Owner's ideas next: more dashboard widgets, settings screen (battery limit etc.).
3. ISO → owner flashes USB.
4. Move day on CachyOS: plug backup stick, `bash ~/Projects/oracle/server/server.sh backup /run/media/son/586D-16CB/oracle-migration-2026-10-10` (sudo: adds tailscale tarballs + photo top-up). Old full-history bundle: ~/Projects/oracle-history-backup-2026-10-11.bundle (copy to stick too).
5. Boot ISO → install → `oracle restore <stick folder>` → Immich Job Queues: thumbnails + transcode missing → phone check.

## Ideas (owner picks)
Secure Boot own keys (sbctl) + UKI (closes TPM gap); btrfs snapshots before `oracle update` (snapper) = undo; dashboard settings file + file navigator + settings screen + keybind editor; one theme colors file applied to all apps; website/download page; `oracle doctor` health check.
