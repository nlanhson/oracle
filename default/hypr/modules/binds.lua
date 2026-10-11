---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local Mod          = "SUPER"
local terminal     = "ghostty"
local fileManager  = "nautilus"
local launcher     = "fuzzel --show drun"
local browser      = "brave-origin"


---------------------
---- KEYBINDINGS ----
---------------------

hl.bind(Mod .. " + W", hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/waybar/launch.sh"))

hl.bind(Mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(Mod .. " + Q", hl.dsp.window.close())
hl.bind(Mod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(Mod .. " + Space", hl.dsp.exec_cmd(launcher))
hl.bind(Mod .. " + R", hl.dsp.exec_cmd(fileManager))
hl.bind(Mod .. " + A", hl.dsp.exec_cmd("swaync-client -t"))
hl.bind(Mod .. " + M", hl.dsp.exec_cmd("oracle shell")) -- Oracle: back to Shell mode
hl.bind(Mod .. " + P", hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/fuzzel/power-menu.sh"))

-- Sleep/Idle
-- WARNING: this SUSPENDS the machine, which stops the home server and
-- makes it unreachable from the phone until the laptop is woken. Deliberate
-- manual sleep only — use Mod+O below to just blank the screen.
hl.bind("XF86Sleep", hl.dsp.exec_cmd("loginctl lock-session && systemctl suspend"))

-- Screen off NOW, without sleeping. Server keeps running and stays reachable.
-- NOTE: hl.dsp.dpms() TOGGLES and ignores its argument, so this is an on/off
-- toggle, not a one-way "off". Press again (or move the mouse) to restore.
-- Do NOT use exec_cmd("hyprctl dispatch dpms off") here — under this lua
-- config hyprctl parses its argument as lua and errors with
-- "')' expected near 'off'", which fails silently from a keybind.
hl.bind(Mod .. " + O", hl.dsp.dpms("off"))

-- Volume
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume -10"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("sh -c 'pactl get-sink-mute @DEFAULT_SINK@ | grep -q yes && pactl set-sink-mute @DEFAULT_SINK@ false; swayosd-client --output-volume 10'"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"))

-- Brightness
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness -5"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("swayosd-client --brightness +5"))

-- Screenshot
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots"))

-- Move focus windows
hl.bind(Mod .. " + left",   hl.dsp.focus({ direction = "left" }))
hl.bind(Mod .. " + right",  hl.dsp.focus({ direction = "right" }))
hl.bind(Mod .. " + up",     hl.dsp.focus({ direction = "up" }))
hl.bind(Mod .. " + down",   hl.dsp.focus({ direction = "down" }))
hl.bind(Mod .. " + J",      hl.dsp.focus({ direction = "left" }))
hl.bind(Mod .. " + L",      hl.dsp.focus({ direction = "right" }))
hl.bind(Mod .. " + I",      hl.dsp.focus({ direction = "up" }))
hl.bind(Mod .. " + K",      hl.dsp.focus({ direction = "down" }))
hl.bind(Mod .. " + F",      hl.dsp.window.float({ action = "toggle" }))

-- Workspace Scroll
hl.bind(Mod .. " + mouse_down",   hl.dsp.focus({ workspace = "e+1" }))
hl.bind(Mod .. " + mouse_up",     hl.dsp.focus({ workspace = "e-1" }))
hl.bind(Mod .. " + right",        hl.dsp.focus({ workspace = "e+1" }))
hl.bind(Mod .. " + left",         hl.dsp.focus({ workspace = "e-1" }))

-- Window move & resize
hl.bind(Mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(Mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Switch workspace
hl.bind(Mod .. " + 1", hl.dsp.focus({ workspace = 1}))
hl.bind(Mod .. " + 2", hl.dsp.focus({ workspace = 2}))
hl.bind(Mod .. " + 3", hl.dsp.focus({ workspace = 3}))
hl.bind(Mod .. " + 4", hl.dsp.focus({ workspace = 4}))
hl.bind(Mod .. " + 5", hl.dsp.focus({ workspace = 5}))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
-- for i = 1, 10 do
--    local key = i % 10 -- 10 maps to key 0
--    hl.bind(Mod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
--    hl.bind(Mod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
-- end