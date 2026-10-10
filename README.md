# Oracle

> Context file for AI coding agents (Claude Code). Read this fully before writing any code.

## TL;DR

Oracle is my own Arch Linux respin (similar in spirit to Omakub / Marchy) with an all-text home screen called the **Oracle TUI shell**. Everything lives in this repo: configs, dotfiles, and an `install.sh` that turns a fresh Arch install into Oracle. Goal: as light and fast as pure Arch, terminal-first, keyboard-driven.

Name is **"Oracle"**, never "Oracle OS". It's named after the information-hub character in Batman, and the whole machine is my own "Batcomputer".

## About the owner (how to work with me)

- I am a UI/UX designer. I have **no coding or engineering background**. I am comfortable with Arch Linux basics.
- Keep answers **short, TL;DR first, no jargon**. Explain simply. Elaborate only when I ask.
- Show only changed code. Don't reprint unchanged files.
- **"Done" requires evidence** (command output, test result), not assumption.
- Prefer production-grade, maintainable solutions over quick hacks, unless I say "just prototype".
- **Never decide anything listed under "Not settled" yet. Ask me first**, with a short recommendation.

## Core principles

1. **Lightweight and fast like pure Arch.** If Oracle ends up as heavy as Ubuntu, Fedora or Mint, the project has failed. Every package and background service must justify itself.
2. Minimal, terminal-first, keyboard-driven.
3. No GNOME, no KDE, no heavy theming.
4. Everything reproducible from this repo on a fresh Arch install.
5. Both **bash and zsh** available.

## Architecture

### Oracle TUI shell (the home screen/launcher)

Not a desktop environment and not a window manager. A pure all-text home screen.

- Look reference: **ascii.rest**. Dark, monospace, bracket-style links like `[github]`, a search line, plain text. Its animated ASCII art is not needed now (maybe later).
- **Text launcher** for everything on the machine: a browsable, searchable list (like double-tab completion).
  - Text apps open in place.
  - GUI apps (e.g. Brave) open through a proper GUI via Hyprland.
- **File manager stays in the text UI.** GUI file manager only when I explicitly ask.
- File navigation feels like plain text: arrow keys, bracket-style selection indicators.

### Sessions / workspaces

- **Workspace 1:** text/ASCII dashboard (btop/htop style).
- **Workspace 2:** Hyprland GUI session for apps like Brave.

### Session approach (exploring, not final)

- Exploring **cage** (single-app fullscreen Wayland compositor) running a fullscreen terminal with **tmux** inside as the home base.
- **Hyprland is NOT the main session** (it's tiling, I don't want that as home). It is an **on-demand fallback** for GUI apps only.

## Look

| Element | Value |
|---|---|
| Background | Near-black |
| Text | Grey / white |
| Accent / highlights | Electric cyan |
| Warnings | Muted dark red |
| Font (suggested, not decided) | IBM Plex Mono |

Keep theming minimal: one palette, applied consistently, no theme engines.

## Security goal

If someone gets physical or SSH access to my machine, they must not be able to use it.

Considering (not final): full-disk encryption with LUKS (extra password at boot), and SSH key-only login (password login off).

## Decided apps

- **Browser:** Brave Origin only. No text-mode browser.
- **Shell:** bash and zsh both installed.

## Not settled yet (ASK before choosing)

- Final choice of **cage** vs another approach for the home session
- Exact **encryption setup** (LUKS layout, SSH hardening details)
- **File manager:** yazi or lf (undecided)
- **App categories** to pre-install (file manager, browser, editor, status/dashboard, etc.). I want to settle categories first, then pick one app per category.
- Font (IBM Plex Mono is only a suggestion)

## Repo goals

- GitHub repo holding all configs and dotfiles.
- `install.sh` that, on a **fresh Arch install**:
  1. Installs the package list
  2. Symlinks dotfiles into place
  3. Is safe to re-run (idempotent), and never silently overwrites existing files (back them up)
  4. Prints clear, plain-language progress and errors

### Proposed structure (suggestion, confirm with me before creating)

```
oracle/
├── README.md
├── install.sh
├── packages/        # package lists, one file per category
├── dotfiles/        # symlinked into $HOME
│   ├── shell/       # bash, zsh
│   ├── tmux/
│   ├── hypr/
│   └── ...
└── scripts/         # launcher, helpers
```

## Reference

- https://github.com/t4t5/omdrop-owl (saved by me as possibly useful: "we might need this")

## Rules for Claude Code

1. **Plan first, then code.** For any non-trivial step, give me a 3-5 line plan and wait for a yes.
2. **One small step at a time.** Don't build the whole system in one go.
3. **Don't add packages casually.** Each package needs a one-line reason. Prefer fewer, lighter tools.
4. **Don't pick from "Not settled".** Ask, with a recommendation and the trade-off in plain words.
5. **Test before saying done.** Show evidence (e.g. `shellcheck install.sh`, a dry run, a VM/container test). If you can't test something (needs real hardware, boot, LUKS), say so clearly.
6. **Never run destructive commands** (disk partitioning, formatting, encryption setup, deleting files) without showing me the exact command first and getting approval.
7. **Keep scripts readable.** Comments in plain language, since I'm not an engineer.
8. Match the palette and the all-text look. No icons-heavy or GUI-style output in the TUI shell.

## Suggested build order

1. **Settle app categories** with me, then pick one app per category.
2. Repo skeleton + `install.sh` (packages + symlinks) with a safe dry-run mode.
3. Shell setup (bash + zsh), palette, font.
4. tmux config and the text home base (cage vs alternative decided here).
5. Text launcher (browse + search, opens text apps in place).
6. Hyprland fallback + GUI app launching (Brave).
7. Workspace 1 dashboard (btop/htop style).
8. Security hardening (LUKS, SSH key-only).
