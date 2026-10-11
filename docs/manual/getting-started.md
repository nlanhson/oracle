# Getting started

## Your first login

Oracle starts on a plain login prompt. Type your username and password.

You land in **Shell mode**:

- **Workspace 1 – home:** the dashboard. On the left, a big clock and the calendar. On the right, your computer's health, volume and brightness, your Claude Code activity and the home server.
- **Workspaces 2, 3 and 4:** terminals, ready for commands.

The bar at the top shows the workspaces. The one you're on shows its name, like `2 terminal`, or the program running in it, like `2 claude`. Switch with `Alt + 1` to `Alt + 4`, or click a number. If you close a terminal, a fresh one takes its place.

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
