# Keys

`Super` is the Windows key.

## Dashboard

| Key | Does |
|---|---|
| `g` | Open the desktop |
| `f` | Files |
| `s` | Settings |
| `u` | Run `oracle update` |
| `m` | Manual: every `oracle` command, what it does, run it from there |

## Terminal sessions (tmux)

| Key | Does |
|---|---|
| `Alt + 1` to `Alt + 4` | Go to workspace (1 is the dashboard) |
| `Ctrl+b` then `c` | Extra window (5, 6, …) |
| `Ctrl+b` then `g` | Open the desktop |
| `Ctrl+b` then `d` | Detach (sessions keep running) |

## Mouse in Shell mode

Click a workspace number in the top bar to switch. On the dashboard, click `[g]ui`, `[f]iles`, `[s]ettings` or `[u]pdate`. In Files, click a line to select it and click it again to open it; the key hints at the bottom are buttons too. In Settings, click a row, click on a slider to set it, or click the left or right half of `◂ ▸` to step. The scroll wheel moves up and down. Right click goes back.

## Desktop (Hyprland)

Your own desktop setup: waybar at the top, the launcher (Oracle's own search box), swaync for notifications, hypridle dims the screen after 5 minutes and turns it off after 7 (the computer never sleeps by itself, so the home server stays up).

| Key | Does |
|---|---|
| `Super + M` | Back to Shell mode, and from there back to the desktop |
| `Super + /` | Manual (pop-up): every `oracle` command, what it does, run it from there |
| `Super + Enter` | Terminal |
| `Super + B` | Brave Origin |
| `Super + R` | Files (Nautilus) |
| `Super + Space` | Search box: type and it finds apps, `oracle` commands, sums (`12*7`, Enter copies the answer), files in your home folder and lock / sleep / restart / shut down. Up/Down moves, Enter opens, Esc closes |
| `Super + A` | Notification Center (also: click the date and time on the bar) |
| `Super + P`, or ⏻ on the top bar | Power menu: lock, sleep, restart, shut down. Sleep pauses the home server |
| `Super + O` | Screen off now (press again or move the mouse to wake it) |
| `Super + W` | Restart the top bar |
| `Super + Q` | Close window |
| `Super + F` | Float / unfloat window |
| `Super + J / L / I / K` | Move focus left / right / up / down |
| `Super + ← / →` | Previous / next workspace |
| `Super + 1`–`5` | Go to workspace |
| `Super + scroll` | Previous / next workspace |
| `Super + drag` | Move window (left button) / resize (right button) |
| `Print` | Screenshot of an area: saved in ~/Pictures/Screenshots and copied, so you can paste it right away. A small thumbnail offers Copy and Edit; click it to open the picture. Esc cancels |
| `Shift + Print` | Screenshot of the whole screen |
| `Super + Print` | Screenshot of the active window |
| `Super + Tab` | Next app: each press goes to the next open app, round and round through all of them |
| ``Super + ` `` | Next window of the same app |
| `Super + Ctrl + F` | Full screen on / off |
| `Super + Ctrl + Q` | Lock the screen |
| `Super + ,` | Settings (pop-up) |
| `Super + Alt + Esc` | Force quit: click the stuck window (Esc cancels) |
| `Super + Shift + 3` / `4` / `5` | Screenshot of the screen / an area / a window (same as the Print keys) |
| Play / pause, next, previous keys | Control any media player |
| `Shift + Alt` + volume or brightness keys | Fine steps (a quarter of the normal step) |
| `Ctrl + Shift` | Switch typing between English and Vietnamese (Telex) |
| Volume and brightness keys | Change them, with an on-screen bar |
| 3 fingers left / right | Previous / next workspace (follows your fingers) |
| 3 fingers up or down | Shell mode rises over the desktop (and goes away again), following your fingers |
| 4 fingers pinch in | App launcher |
| `Super` + pinch | Zoom in on the pointer, pinch back to zoom out |

## Terminal (Ghostty)

| Key | Does |
|---|---|
| `Ctrl + Shift + O` / `E` | Split right / down |
| `Ctrl + Shift + J / L / I / K` | Move between splits |
| `Ctrl + Alt + I / K` | Scroll up / down |
| `Ctrl + Alt + L` | Clear the screen |

Your terminal settings are in `~/.config/ghostty/mine`.

## Typing commands (zsh)

| Key | Does |
|---|---|
| `Tab` | Completion menu, move with the arrows |
| `→` | Accept the grey suggestion (from your history) |
| `Ctrl + G` | Pick a folder you've been to, type to filter, Enter goes there |
| `z name` | Jump to the folder you use most that matches `name` |

Shortcuts: `ff` shows system info, `btop` shows what's using the computer, `i <name>` installs a package.

## Change a key

Open `~/.config/hypr/hyprland.lua` and add lines at the end. They load last, so they win:

```lua
hl.bind("SUPER + B", hl.dsp.exec_cmd("firefox"))
```

Log out of the desktop and back in to apply.

### Also built in

- Dialogs (file pickers, password prompts, Properties, volume control) open floating in the middle, with the rest dimmed.
- Picture-in-picture video floats small in the bottom-right corner, on top, on every workspace.
- Two-finger click is the right click; two-finger swipe goes back and forward in Brave Origin; tap to click is on; the pointer hides while you type.
- What you copy stays on the clipboard after the app quits. Space in Files previews a file.
- Settings has Trackpad and Keyboard groups (tracking speed, tap to click, natural scrolling, key repeat).
