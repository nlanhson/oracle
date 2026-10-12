# Keys

`Super` is the Windows key.

## Dashboard

| Key | Does |
|---|---|
| `g` | Open the desktop |
| `f` | Files |
| `s` | Settings |
| `u` | Run `oracle update` |

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

Your own desktop setup: waybar at the top, fuzzel to launch apps, swaync for notifications, hypridle dims the screen after 5 minutes and turns it off after 7 (the computer never sleeps by itself, so the home server stays up).

| Key | Does |
|---|---|
| `Super + M` | Back to Shell mode |
| `Super + Enter` | Terminal |
| `Super + B` | Brave Origin |
| `Super + R` | Files (Nautilus) |
| `Super + Space` | App launcher |
| `Super + A` | Notifications |
| `Super + P` | Power menu: lock, sleep, restart, shut down. Sleep pauses the home server |
| `Super + O` | Screen off now (press again or move the mouse to wake it) |
| `Super + W` | Restart the top bar |
| `Super + Q` | Close window |
| `Super + F` | Float / unfloat window |
| `Super + J / L / I / K` | Move focus left / right / up / down |
| `Super + ← / →` | Previous / next workspace |
| `Super + 1`–`5` | Go to workspace |
| `Super + scroll` | Previous / next workspace |
| `Super + drag` | Move window (left button) / resize (right button) |
| `Print` | Screenshot of an area (saved in ~/Pictures/Screenshots) |
| `Ctrl + Shift` | Switch typing between English and Vietnamese (Telex) |
| Volume and brightness keys | Change them, with an on-screen bar |

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

## Change a key

Open `~/.config/hypr/hyprland.lua` and add lines at the end. They load last, so they win:

```lua
hl.bind("SUPER + B", hl.dsp.exec_cmd("firefox"))
```

Log out of the desktop and back in to apply.
