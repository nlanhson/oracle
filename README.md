# Oracle

> A terminal-first, keyboard-driven Arch Linux setup, inspired by the Batcomputer. One repo, one script, one fresh Arch install turned into a personal master machine.

**Status:** Early planning / design. No install script exists yet. Sections marked **[DECIDED]** are settled; **[OPEN]** are not.

---

## 1. What Oracle is (and is not)

Oracle is an **opinionated setup layer on top of vanilla Arch Linux**: a dotfiles repo plus an `install.sh` that turns a blank base Arch install into a fully configured system.

- It is **not** a new distro in the strict sense. It has no repos, no custom kernel, no custom ISO, and no separate maintainers. It uses stock Arch packages and the AUR.
- It **is** a "respin / setup script" in the same family as [Omarchy](https://github.com/basecamp/omarchy), [Omakub](https://omakub.org), and, loosely, LARBS. Many such projects call themselves "distros" informally. Calling Oracle a distro is fine for personal use; it is a naming choice, not a technical claim.
- It does **not** need to be published as an official distro.

**Name [DECIDED]:** `Oracle` (not "Oracle OS"). Reasons: cleaner, reads as an identity rather than a spec sheet, and avoids sounding like a product competing with Oracle Corporation. The name comes from the Batman lore character Oracle, the information hub who runs everything from a keyboard.

**Acronym [OPEN]:** Not chosen yet. Candidates:
1. **O**pinionated **R**aw **A**rch **C**ommand-line **L**ayer **E**nvironment
2. **O**perator-**R**un **A**rch **C**ommand-line **L**ab **E**nvironment
3. **O**ne-repo **R**eproducible **A**rch **C**onfig **L**oader **E**verywhere

---

## 2. Vision and design principles [DECIDED]

**Inspiration:** the Batcomputer. A "master machine" that feels powerful, alive, and no-nonsense. All text, all data.

**Core principles**

1. **Terminal-first, GUI-optional.** The default experience is a mostly blank screen with plain text. The user does not rely on a GUI.
2. **Keyboard-driven.** Everything navigable with arrow keys / keyboard. For example, a file manager is pure text: a list of entries, arrow keys to move, and the selected entry marked with square brackets, like `[ selected-item ]`. This is a TUI look and feel, not "a terminal window inside a desktop."
3. **Minimal and lightweight.** Few packages, low resource use, fast boot.
4. **Little theming.** A cohesive but restrained look. No heavy ricing, no elaborate theming system.
5. **Two modes:**
   - **Primary mode:** terminal-first text environment (described above).
   - **Secondary mode:** **Hyprland** as a fallback GUI for when a task is easier with a graphical interface (browsers, design tools, anything awkward in a terminal).
6. **Reproducible.** Everything lives in the repo. A fresh machine should reach "my system" with a handful of commands.

**Explicitly rejected:** GNOME and KDE (too heavy, too GUI-centric).

---

## 3. Installation flow (target experience) [DECIDED at a high level]

The base Arch install stays manual (or via `archinstall`) because disk operations are risky to script badly. Oracle takes over after the base system boots.

1. **Boot the Arch ISO** and complete a normal base install: partitioning, `pacstrap`, bootloader, user creation, networking.
2. **Reboot into the fresh base system** and connect to the internet.
3. **Install git:**
   ```bash
   sudo pacman -S git
   ```
4. **Clone the repo.** `git clone <url>` creates a folder named after the repo in the current directory. A second argument sets the destination:
   ```bash
   git clone <repo-url> ~/oracle
   cd ~/oracle
   ```
5. **Make the script executable (once) and run it:**
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
   Notes: `cd` goes into the *folder*, never into the script. `bash install.sh` also works without `chmod`, but it ignores the shebang and always uses bash, which is fine since the script is bash.

After step 5 the script does everything else with no further manual work (aside from any prompts it deliberately shows).

---

## 4. What `install.sh` should do [OPEN: details]

High-level responsibilities:

1. Sanity checks (running on Arch, not as root unless required, network available).
2. Full system update (`pacman -Syu`).
3. Install an AUR helper (e.g. `yay` or `paru`; **[OPEN]** which one).
4. Install packages from plain-text package lists (official repos and AUR kept in separate files).
5. Symlink dotfiles from the repo into `$HOME` / `~/.config` (backing up anything that already exists).
6. Set up the shell, services (`systemctl enable ...`), and default applications.
7. Optionally show a minimal TUI menu to choose a **profile**.

**Script quality requirements**

- **Idempotent:** safe to re-run without breaking or duplicating anything.
- **Fail loudly:** `set -euo pipefail`, clear error messages, non-zero exit on failure.
- **Readable and commented:** the maintainer works largely through AI assistance, so scripts should be simple and easy to follow rather than clever.
- **Linted:** pass `shellcheck`.
- **Tested in a VM** (QEMU/KVM, VirtualBox, or similar) on a fresh Arch install before anything is called done.
- **No dependence on Claude or any AI at install time.** The script must run on its own. AI is used to *write and refine* the script, not to run the install.

**Profiles [OPEN]:** possible split such as `minimal` (terminal-only), `dev`, and `full` (adds Hyprland GUI mode). Not finalized.

---

## 5. Proposed repository structure [OPEN: proposal only]

```
oracle/
├── README.md
├── install.sh              # entry point
├── packages/
│   ├── base.txt            # official repo packages (core terminal system)
│   ├── aur.txt             # AUR packages
│   └── hyprland.txt        # GUI-mode packages
├── dotfiles/
│   ├── shell/              # shell config, prompt
│   ├── tui/                # terminal-first tools: file manager, launcher, etc.
│   └── hyprland/           # secondary GUI mode config
├── scripts/                # helper scripts called by install.sh
└── docs/                   # design notes, decisions
```

---

## 6. Open decisions

None of these have been chosen. Candidates are suggestions, not commitments.

| Area | Question | Candidate ideas |
|---|---|---|
| TUI file manager | Which tool gives the plain-text, arrow-key, `[ bracket ]` selection feel? | yazi, ranger, nnn, lf (or a custom script) |
| Primary "screen" | What does the blank-screen, few-lines-of-text home look like? | Custom TUI menu/launcher, tmux-based layout, or a shell-script-driven menu |
| Terminal emulator | Which one, for the primary mode? | foot, kitty, alacritty |
| Shell | Which shell and prompt? | zsh, fish, bash |
| AUR helper | yay vs paru | |
| Bootloader | Assumed from the base install, not scripted | systemd-boot, GRUB |
| Hyprland mode | How is it launched alongside the terminal-first mode? | Separate session at login, or a keybind/command that starts it |
| Profiles | Which profiles exist and what is in each? | minimal / dev / full |
| Installer UI | Silent install vs a small TUI menu | |
| Acronym | Which expansion of ORACLE (see section 1)? | |

---

## 7. Reference projects

- **Omarchy**: opinionated Arch + Hyprland setup; the closest conceptual model for "Arch with an automated, opinionated setup."
- **Omakub**: the equivalent for Ubuntu.
- **LARBS**: script-driven Arch rice bootstrapping.
- **Garuda / EndeavourOS**: Arch-based projects that commonly call themselves distros.

---

## 8. Instructions for an AI assistant working on this repo

If you are an AI session picking this project up from this README, follow these guidelines.

**Context to hold**

- This is an Arch-based setup layer (see section 1), not a from-scratch distro. Do not suggest Linux From Scratch or building a custom kernel/toolchain.
- The identity is **terminal-first, minimal, keyboard-driven, Batcomputer-inspired**. Do not propose GNOME, KDE, or heavy theming. Hyprland is the secondary GUI mode only.
- The maintainer is comfortable with Arch and its concepts but works primarily through AI-assisted coding. Explain commands and non-obvious choices briefly, and prefer simple, readable solutions.

**How to work**

- Be concise. Lead with the answer or the code; skip preambles and recaps.
- When changing a file, show only the changed parts, not the whole file again.
- Default to production-grade, maintainable solutions (idempotent, linted, error-handled). Only cut corners if the maintainer explicitly says "just prototype."
- Do not mark anything "done" without evidence: shellcheck output, a successful VM run, or a captured log.
- Do not make decisions in section 6 silently. Propose options with a recommendation, wait for the maintainer's choice, then record the decision in this README.
- Keep this README current: when a decision is made, move it from **[OPEN]** to **[DECIDED]** and update the structure section to match reality.

**Good first tasks**

1. Choose and record the open decisions in section 6 (start with TUI file manager and shell).
2. Create `packages/base.txt` with a minimal terminal-only package set.
3. Write a first `install.sh` covering: sanity checks, `pacman -Syu`, package install from `packages/base.txt`, and dotfile symlinking with backups.
4. Set up a VM test loop and document it in `docs/`.
5. Design the terminal-first "home screen" and file-manager look (plain text, arrow-key navigation, bracket-marked selection).
6. Add the Hyprland secondary mode as a separate profile.

---

## 9. Changelog

- Initial project definition: name chosen (Oracle), vision, install flow, and open decisions captured.
