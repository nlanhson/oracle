# Getting started

## Your first login

Oracle starts on a plain login prompt. Type your username and password.

You land in **Shell mode**:

- **Workspace 1 – home:** the dashboard. On the left, a big clock and the calendar. On the right, your computer's health, volume and brightness, your Claude Code activity and the home server.
- **Workspaces 2, 3 and 4:** terminals, ready for commands.

The bar at the top shows the workspaces. The one you're on shows its name, like `2 terminal`, or the program running in it, like `2 claude`. Switch with `Alt + 1` to `Alt + 4`, or click a number. If you close a terminal, a fresh one takes its place.

## First run

The first time you log in after a fresh install, a short **welcome guide** opens before the dashboard. It takes about a minute, one choice per screen:

1. **Welcome.** What this is.
2. **Wi-Fi.** Only if you're offline: pick a network.
3. **Look.** Accent colour and text size. You see the change as you make it.
4. **Wallpaper.** Black, or a picture from `~/Pictures`, for the desktop.
5. **Keys to know.** The handful of shortcuts that matter.
6. **You're set.** Where to change things later.

Every step has **skip**, **back** works (`Esc`, or right click), and nothing it sets is permanent: it all lives in settings (`s`). `Esc` on the first screen skips the whole guide. It runs by itself only once. Run it again any time with `oracle welcome`. It does not start by itself after `oracle update` on an existing install.

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
- **System:** time zone, keyboard layout, accent color, desktop wallpaper (a picture from ~/Pictures, or black), and **about** (user, Oracle version, RAM, disk).
- **Buttons:** update, rollback (take back an update), restart, shut down.

Keyboard layout and screen scale apply the next time Shell mode or the desktop starts.

You can also use the mouse everywhere: see [Keys](keys.md#mouse-in-shell-mode).

After 5 minutes without touching anything, the screen dims; after 7 it turns off. On battery that happens sooner, after 2 and 3 minutes, and the keyboard light goes off with the screen. A playing video keeps the screen on. Closing the lid also turns the screen off. The computer keeps running either way, so the home server stays up.

You can use the mouse in Shell mode too: click a workspace number, scroll, and select text to copy it.

## The desktop

Press `g` on the dashboard (or type `oracle gui`) to open the desktop, Hyprland. Use it for the browser and other graphical apps. Press `Super + M` (or type `oracle shell`) to go back. The desktop keeps running behind Shell mode, so the browser and every other app are still there when you return with `Super + M` (or `g` on the dashboard).

To type Vietnamese in the desktop, press `Ctrl + Shift` to switch between English and Vietnamese (Telex: `aa` = â, `s` = sắc, …). Shell mode is English only.

Your terminal sessions keep running while you're in the desktop. Apps you opened in the desktop close when you go back.

### One look

Every part of the desktop (bar, launcher, notifications, volume pill, lock screen, window borders, Files and other apps) takes its greys, corners, spacing and fonts from one file (the font is Inter, a clear sans that also covers Vietnamese; terminals and Shell mode keep JetBrains Mono): `~/.local/share/oracle/default/look/tokens`. To change a value yourself, copy the line into `~/.config/oracle/tokens` (same format, it wins), then run `oracle look`. Your accent colour in Settings is used too. To add your own touches to one part, write below the import line in its file in `~/.config` (for example `~/.config/waybar/style.css`).

## Power and battery

- **Power button:** a press never turns Oracle off, because it is also your home server. On the desktop a press opens the power menu (the same as `Super + P`); in Shell mode and at the login screen it does nothing. To force it off, hold the button for 5 seconds: Oracle shuts down cleanly.
- **Battery:** when running on battery, Oracle tells you at 20% ("Plug in soon") and at 10% ("Plug in now", this one stays until you close it). At 4% it shuts down cleanly after 60 seconds, so the photo database is never cut off mid-write. Plug in during those 60 seconds and nothing happens. It never sleeps. The percentages are of the real battery, so with a charge limit of 50% you still get the warnings at 20 and 10.

## When something needs you

Oracle looks for problems every 5 minutes and tells you once, in a short notification that ends with what to do:

| You see | It means | What to do |
|---|---|---|
| Disk almost full: Disk is 92% full | Less than a tenth of the disk is free | Free some space: `oracle files`, empty the trash |
| Something stopped working: The service X stopped working | A background service failed | `oracle doctor` shows which, and how to fix it |
| Brave Origin quit unexpectedly | An app crashed | Open it again |
| This Wi-Fi needs a sign-in | A café or hotel Wi-Fi wants you to accept its page | Click the notification: the sign-in page opens in the browser |
| Immich is not working | A home server app stopped | `oracle doctor` |
| Updates are ready | New programs or a newer Oracle are waiting | `oracle update`, when it suits you |

The same alert never comes twice in one day. In Shell mode there are no notifications: the same lines show at the top of the dashboard, with a red `!`. To turn the alerts and the update notice off: `systemctl --user mask --now oracle-watch.timer` (`unmask` turns them back on).

## First things to do

1. **Wi-Fi:** if you didn't connect during install, type `nmtui`.
2. **Update:** type `oracle update`.
3. **Home server:** if you have a backup, type `oracle restore <backup folder>` (see [Backup and home server](backup.md)).
4. **Recovery key:** make sure you wrote down the key shown at the end of the install. You need it if the disk ever fails to unlock by itself.

## Getting help

Something feels off? Type `oracle doctor`. It checks the whole computer (services, disk space, disk unlock, boot menu, snapshots, network, firewall, updates, battery limit, power button, battery watch, alerts, update check, clock, home server) and prints one line per check:

- `ok`: working.
- `!`: works, but worth a look. The line says what to type.
- `x`: broken. The line says how to fix it.

It only looks, it never changes anything. It asks for your password once, to read the disk and boot settings.

Forgot a command? Press `m` on the dashboard, `Super + /` on the desktop, or type `oracle manual`. It lists every `oracle` command with what it does, when to use it and an example. Press `/` to search, Enter to run the selected one (risky ones like update, rollback and restore ask first), `q` to close. See [Keys](keys.md) for shortcuts.

## AI helpers

Claude Code (`claude`) and OpenCode (`opencode`) come installed. Type either one in a terminal.
