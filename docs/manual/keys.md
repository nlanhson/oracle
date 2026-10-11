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

## Desktop (Hyprland)

The bar, launcher, notifications, lock screen and control center come from [Noctalia](https://github.com/noctalia-dev/noctalia).

| Key | Does |
|---|---|
| `Super + M` | Back to Shell mode |
| `Super + Enter` | Terminal |
| `Super + B` | Brave Origin |
| `Super + E` | Files (Nautilus) |
| `Super + T` | Text editor |
| `Super + C` | Calculator |
| `Super + Space` | App launcher |
| `Super + X` | Control center (Wi-Fi, Bluetooth, sound) |
| `Super + Z` | Noctalia settings |
| `Super + V` | Clipboard history |
| `Super + A` | Notifications |
| `Super + L` | Lock the screen |
| `Super + Alt + C` | Lock, log out, restart, shut down |
| `Super + Q` | Close window |
| `Super + F` / `Super + D` | Fullscreen / maximize |
| `Super + Alt + Space` | Float / unfloat window |
| `Super + ←↑→↓` | Move focus |
| `Super + Shift + ←↑→↓` | Move window |
| `Super + 1`–`3` | Go to workspace |
| `Super + Shift + Ctrl + 1`–`3` | Move window to workspace |
| `Super + S` | Scratchpad (`Super + Shift + S` sends a window there) |
| `Super + drag` | Move window (left button) / resize (right button) |
| `Super + +` / `Super + -` | Zoom in / out |
| `Print` / `Super + Print` | Screenshot of an area / the whole screen |
| `Super + P` | Color picker |
| `Ctrl + Shift + Esc` | Task manager (btop) |
| `Alt + Tab` | Next window |

## Change a key

Open `~/.config/hypr/hyprland.lua` and add lines at the end. They load last, so they win:

```lua
hl.bind("SUPER + B", hl.dsp.exec_cmd("firefox"))
```

Log out of the desktop and back in to apply.
