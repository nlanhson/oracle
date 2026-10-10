# Oracle design (v1)

> Living document. About 50% complete on purpose: enough to start building, and it fills in as we go.
> Date: 2026-10-10

## What Oracle is

Oracle replaces CachyOS on the user's laptop (ASUS ROG Zephyrus G14, GA401QC). The laptop is both:

1. **The home server.** It stays at home, plugged in, lid usually closed, always on. It runs today's server setup **unchanged**.
2. **The daily computer.** Mostly terminal work (vibe coding with Claude Code), with a GUI when needed.

Success = after the move, the phone still backs up photos to Immich, the exit node still works, the laptop survives a power cut and comes back by itself, and daily use feels lighter and faster than CachyOS.

## Two modes

| Mode | What it is | Used for |
|---|---|---|
| **Shell** (default) | `cage` running one fullscreen terminal (`foot`) with `tmux` inside. Starts automatically after login on TTY1. | Home dashboard, coding, everything text |
| **GUI** (on demand) | Hyprland on its own TTY, started only when asked. | Brave, Facebook, anything graphical |

- Shell mode has several sessions through tmux (e.g. home, code, server).
- Switching: a `gui` command in Shell starts or jumps to GUI mode, and one Hyprland key jumps back to Shell.
- **Vietnamese typing (fcitx5 + Bamboo) only in GUI mode.** Shell mode doesn't need it.
- Known trade-off we accept: the two modes have separate clipboards.

### Shell home screen

All-text, like ascii.rest: near-black background, grey/white text, electric cyan accents, muted dark red for warnings. It shows the machine's state at a glance: server apps up/down, CPU/RAM/disk/temperature, battery and charging, network/Tailscale, plus bracket links like `[code]` `[files]` `[server]` `[gui]`. Built in step 4.

## Server (moved as-is)

- Docker + Dockge, same folders (`~/docker/<app>/`, `~/dockge/`) and same ports: Immich `localhost:2283`, Dockge `localhost:5001`.
- Tailscale on the host. Restore the old Tailscale state so the laptop keeps `100.108.66.46` and the phone keeps working. The `vpn` stack (Gluetun + `vpn-exit`) moves with its folder.
- Network: NetworkManager + systemd-resolved, with `/etc/resolv.conf` linked to the resolved stub. This makes Tailscale names (MagicDNS) work, so the phone can later use a name instead of an IP.
- Lid: `logind` ignores the lid (never sleeps). The screen turns off when the lid closes (in Shell mode via a small lid watcher, because cage has no lid support).
- Immich must be **3.2.2 or newer** to restore the current database dump.

## Disk and security

- **Full-disk encryption (LUKS2), unlocked automatically by the laptop's TPM chip.** It boots by itself after a power cut, with no password needed at boot. Disk taken out = unreadable; whole laptop stolen = still needs the login password.
- A recovery key is written down and kept off the laptop (needed if the TPM unlock ever fails, e.g. after a firmware update).
- btrfs filesystem (same as today).
- SSH: key-only login, password login off (if SSH is enabled at all).

## Hardware and power

- Keep the NVIDIA GPU asleep: both compositors are pinned to the AMD iGPU (same trick as today).
- Battery charge capped around 80% if the model supports it (always plugged in).
- Details come from the research in progress (CachyOS inventory, power tuning).

## Default apps (decided by Claude to keep moving; swap anytime)

| Category | App |
|---|---|
| Terminal | foot |
| Sessions/splits | tmux |
| Shells | bash + zsh (zsh default, with autosuggestions) |
| File manager | yazi |
| Text editor | micro (simple keys: Ctrl+S save, Ctrl+Q quit) |
| Dashboard | btop + Oracle home screen |
| Wi-Fi | NetworkManager (`nmtui`) |
| Sound | PipeWire + `wiremix` |
| Clipboard | wl-clipboard |
| Browser | Brave Origin (GUI mode) |
| Vietnamese | fcitx5 + Bamboo (GUI mode) |
| Font | IBM Plex Mono |
| Coding | git, gh, Claude Code |

## Repo layout

```
oracle/
├── README.md          # context for AI agents
├── install.sh         # fresh Arch → Oracle (idempotent, --dry-run, backs up before replacing)
├── packages/          # package lists, one file per category
├── dotfiles/          # symlinked into $HOME
├── system/            # files copied into /etc (logind lid, resolved link, etc.)
├── scripts/           # oracle helpers: gui switch, lid watcher, home screen
└── docs/              # specs, migration runbook
```

## Build order

0. **Back up** photos, database dump, server folders, secrets and Tailscale state to USB (in progress).
1. **Repo skeleton + `install.sh`** with `--dry-run`, tested in an Arch container (`shellcheck` + dry run + real run in a container).
2. **Shell mode:** cage + foot + tmux autostart, palette, font, zsh/bash.
3. **GUI mode:** Hyprland on demand + switching + Vietnamese + Brave.
4. **Home screen** dashboard.
5. **Server pieces:** Docker, Dockge, Tailscale, lid handling, network/DNS.
6. **Install runbook:** Arch install with LUKS2 + TPM auto-unlock (tested in a VM first), then restore the server from the backup.
7. **Move day:** reinstall the laptop, run `install.sh`, restore, and check the phone backup works end to end.

## Rules that still apply

- Nothing destructive (partitioning, formatting, deleting) without showing the exact command and getting a yes.
- "Done" needs evidence.
- Anything that needs real hardware (TPM unlock, lid, boot) is tested on a VM first where possible, and its limits are stated clearly.
