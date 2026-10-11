# Getting started

## Your first login

Oracle starts on a plain login prompt. Type your username and password.

You land in **Shell mode**:

- **Workspace 1 – home:** the dashboard. On the left, a big clock and the calendar. On the right, your computer's health, volume and brightness, your Claude Code activity and the home server.
- **Workspaces 2, 3 and 4:** terminals, ready for commands.

The bar at the top shows the workspaces. The one you're on shows its name, like `2 terminal`, or the program running in it, like `2 claude`. Switch with `Alt + 1` to `Alt + 4`, or click a number. If you close a terminal, a fresh one takes its place.

## Files

Press `f` on the dashboard (or type `oracle files`). Folders open and close in place, like a tree. Pick a file and Oracle asks what to do:

- **Text files:** read, edit, or edit as admin (for system settings files).
- **Pictures, PDFs and other files:** open in the desktop. Oracle switches to the desktop and opens the file there.

Work with files using these keys:

| Key | Does |
|---|---|
| `c` / `x` | Copy / cut the selected file or folder |
| `p` | Paste into the selected folder (or next to the selected file) |
| `r` | Rename |
| `n` | New folder |
| `d` | Move to the trash (restore it from Files in the desktop) |
| `/` | Search by name. `Esc` clears the search |
| `.` | Show or hide hidden files |

## Settings

Press `s` on the dashboard (or type `oracle settings`). Move with the arrow keys, change a value with left and right, open a list with Enter. In long lists, just type to search.

- **Screen:** brightness, night light (off, 6 PM to 6 AM, or always on), text size in Shell mode, screen scale in the desktop.
- **Sound:** volume, mute, and where sound plays (speakers, headphones, Bluetooth).
- **Battery:** where charging stops.
- **Network:** Wi-Fi and Bluetooth, on/off, and picking a network or device.
- **System:** time zone, keyboard layout, accent color, desktop wallpaper (a picture from ~/Pictures, or black), and **about** (user, Oracle version, memory, disk).
- **Buttons:** update, rollback (take back an update), restart, shut down.

Keyboard layout and screen scale apply the next time Shell mode or the desktop starts.

You can also use the mouse everywhere: see [Keys](keys.md#mouse-in-shell-mode).

After 5 minutes without touching anything, the screen dims; after 7 it turns off. Closing the lid also turns the screen off. The computer keeps running either way, so the home server stays up.

You can use the mouse in Shell mode too: click a workspace number, scroll, and select text to copy it.

## The desktop

Press `g` on the dashboard (or type `oracle gui`) to open the desktop, Hyprland. Use it for the browser and other graphical apps. Press `Super + M` (or type `oracle shell`) to go back.

To type Vietnamese in the desktop, press `Ctrl + Shift` to switch between English and Vietnamese (Telex: `aa` = â, `s` = sắc, …). Shell mode is English only.

Your terminal sessions keep running while you're in the desktop. Apps you opened in the desktop close when you go back.

## First things to do

1. **Wi-Fi:** if you didn't connect during install, type `nmtui`.
2. **Update:** type `oracle update`.
3. **Home server:** if you have a backup, type `oracle restore <backup folder>` (see [Backup and home server](backup.md)).
4. **Recovery key:** make sure you wrote down the key shown at the end of the install. You need it if the disk ever fails to unlock by itself.

## Getting help

Type `oracle` to see all Oracle commands. See [Keys](keys.md) for shortcuts.
