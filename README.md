# Oracle

AI-only context. Owner never reads repo. Keep terse.

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
Never run installer for real on current machine (CachyOS). Test in `archlinux` docker container.

Install: `curl -fsSL https://raw.githubusercontent.com/nlanhson/oracle/main/install.sh | bash`

## v1 (now)
Hyprland + kitty + Brave Origin (AUR `brave-origin-bin` via yay). Hyprland autostart on tty1.

## Later (one at a time, owner picks when)
- Shell mode (default after login): cage + foot + tmux. Home dashboard + coding. GUI mode = Hyprland on demand. Separate clipboards accepted.
- Look: near-black bg, grey/white text, electric cyan accent, muted dark red warn. IBM Plex Mono. ascii.rest style, bracket links `[gui]`.
- Vietnamese: fcitx5 + fcitx5-bamboo, GUI only. Brave flags in `~/.config/brave-origin-flags.conf`: `--ozone-platform=wayland --enable-wayland-ime --wayland-text-input-version=3`.
- Server, moved unchanged: github.com/nlanhson/homeserver. Docker + Dockge (`~/docker/<app>`, `~/dockge`), Immich :2283 (>=3.2.2), Dockge :5001, vpn stack. Tailscale: restore state to keep 100.108.66.46. Net: NetworkManager + systemd-resolved, `/etc/resolv.conf` → `../run/systemd/resolve/stub-resolv.conf` (MagicDNS). logind ignore lid + IdleAction. Screen off on lid (cage: needs watcher). Docker ports bypass ufw.
- Hardware (ASUS G14 GA401QC, AMD iGPU + RTX 3050): `linux` + `nvidia-open`. Pin compositor to iGPU (`/etc/udev/rules.d/61-amd-igpu.rules`: `SUBSYSTEM=="drm", KERNEL=="card[0-9]*", KERNELS=="0000:04:00.0", SYMLINK+="dri/amd-igpu"`; then `AQ_DRM_DEVICES`/`WLR_DRM_DEVICES=/dev/dri/amd-igpu`), dGPU sleeps D3cold. mkinitcpio `MODULES=(amdgpu)`. Battery cap 80 via sysfs `charge_control_end_threshold` + oneshot unit (resets each boot). power-profiles-daemon balanced. zram-generator (ram, zstd), swappiness 150.
- Disk: LUKS2 + TPM auto-unlock (`systemd-cryptenroll`), systemd-boot UKI, btrfs. Must boot unattended after power cut. No autologin. SSH key-only.
- Default apps when needed: yazi, micro, btop, nmtui, wiremix, wl-clipboard, bash + zsh.
