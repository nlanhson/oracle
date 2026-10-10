# Getting started

## Your first login

Oracle starts on a plain login prompt. Type your username and password.

You land in **Shell mode**:

- **Window 0 – home:** the dashboard with your computer's health, the home server, a calendar and your Claude Code activity.
- **Window 1 – bash:** a terminal, ready for commands.

The bar at the bottom shows your open windows and the time. Switch windows with `Ctrl+b` then the window number, or click them.

## The desktop

Press `g` on the dashboard (or type `oracle gui`) to open the desktop, Hyprland. Use it for the browser and other graphical apps. Press `Super + M` (or type `oracle shell`) to go back.

Your terminal sessions keep running while you're in the desktop. Apps you opened in the desktop close when you go back.

## First things to do

1. **Wi-Fi:** if you didn't connect during install, type `nmtui`.
2. **Update:** type `oracle update`.
3. **Home server:** if you have a backup, type `oracle restore <backup folder>` (see [Backup and home server](backup.md)).
4. **Recovery key:** make sure you wrote down the key shown at the end of the install. You need it if the disk ever fails to unlock by itself.

## Getting help

Type `oracle` to see all Oracle commands. See [Keys](keys.md) for shortcuts.
