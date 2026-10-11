# Keys

`Super` is the Windows key.

## Dashboard

| Key | Does |
|---|---|
| `g` | Open the desktop |
| `u` | Run `oracle update` |

## Terminal sessions (tmux)

| Key | Does |
|---|---|
| `Alt + 1` to `Alt + 4` | Go to workspace (1 is the dashboard) |
| `Ctrl+b` then `c` | Extra window (5, 6, …) |
| `Ctrl+b` then `g` | Open the desktop |
| `Ctrl+b` then `d` | Detach (sessions keep running) |

## Desktop (Hyprland)

| Key | Does |
|---|---|
| `Super + Enter` | Terminal |
| `Super + B` | Brave browser |
| `Super + Q` | Close window |
| `Super + F` | Float / unfloat window |
| `Super + ←↑→↓` or `Super + J I L K` | Move focus |
| `Super + 1`–`5` | Go to workspace |
| `Super + scroll` | Next / previous workspace |
| `Super + drag` | Move window (left button) / resize (right button) |
| `Super + O` | Turn the screen off / on |
| `Super + M` | Back to Shell mode |
| Volume and brightness keys | Work as usual |

## Change a key

Open `~/.config/hypr/hyprland.lua` and add a line before `O.apply()`:

```lua
O.binds["SUPER + B"] = "exec firefox"   -- change
O.binds["SUPER + O"] = false            -- remove
```

Log out of the desktop and back in to apply.
