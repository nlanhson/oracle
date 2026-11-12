-------------------
---- BEHAVIOUR ----
-------------------
-- Oracle Feel slice 10 (docs/feel.md, "Behaviour"): the rules under the look, copied from macOS Sequoia 15. Trackpad: input.lua.
local S = require("modules.settings")

-- Focus keeps following the pointer (owner's choice, input.lua: follow_mouse = 1); scrolling goes to the window under it

-- Key repeat: a short pause, then steady (macOS "key repeat" + "delay until repeat"). Settings: Keyboard > key repeat
local rep = ({ slow = { 500, 15 }, normal = { 300, 30 }, fast = { 200, 40 } })[S.keyrepeat or "normal"] or { 300, 30 }
hl.config({ input = { repeat_delay = rep[1], repeat_rate = rep[2] } })

-- Opening a link or a file brings that app forward, and takes you to its workspace; a new window never hides behind a full-screen one
-- (2 = the full-screen window steps back, like a Mac Space switch)
hl.config({ misc = { focus_on_activate = true, on_focus_under_fullscreen = 2, enable_anr_dialog = true } }) -- anr = "not responding" dialog

-- Pointer hides while you type, back when you move (macOS)
hl.config({ cursor = { hide_on_key_press = true } })

-- Sheets: the rest dims behind a modal dialog (macOS dims the window a sheet belongs to)
hl.config({ decoration = { dim_modal = true } })

-- Dialogs, file pickers and password prompts float in the centre and never tile; the screen dims around them (macOS sheets)
local DIALOG = "^(xdg-desktop-portal-gtk|xdg-desktop-portal-kde|hyprpolkitagent|org\\.hyprland\\.polkit.*|polkit-gnome-authentication-agent-1|zenity)$"
local TITLE  = "^(Open Files?|Open Folder|Save Files?|Save As|Select .*|Choose .*|Open With|Rename.*)$"
hl.window_rule({ name = "oracle-dialog",       match = { class = DIALOG },           float = true, center = true, dim_around = true })
hl.window_rule({ name = "oracle-dialog-title", match = { title = TITLE },            float = true, center = true, dim_around = true })
hl.window_rule({ name = "oracle-modal",        match = { modal = true },             float = true, center = true })
hl.window_rule({ name = "oracle-small-tools",  match = { class = "^(org\\.pulseaudio\\.pavucontrol|com\\.gabm\\.satty|nm-connection-editor|blueman-manager)$" },
                float = true, center = true, size = "900 620" })
hl.window_rule({ name = "oracle-properties",   match = { title = "^.* Properties$" }, float = true, center = true })

hl.window_rule({ name = "oracle-settings", match = { class = "^oracle\\.settings$" }, float = true, center = true, force_rgbx = true, size = "(monitor_w*0.6) (monitor_h*0.88)" }) -- Super+comma pop-up: fits the screen, the list scrolls inside

-- Picture in picture: small, bottom-right, on top, on every workspace, never takes the keyboard (macOS PiP)
hl.window_rule({ name = "oracle-pip", match = { title = "^(Picture[ -]in[ -][Pp]icture)$" },
                 float = true, pin = true, keep_aspect_ratio = true, no_initial_focus = true,
                 size = "480 270", move = "monitor_w-window_w-24 monitor_h-window_h-24" })
hl.on("window.active", function(w) -- kept on top: raise it again whenever another window comes forward
  if w and w.title:match("^Picture[ -]in[ -][Pp]icture$") then return end
  for _, p in ipairs(hl.get_windows({ floating = true })) do
    if p.title:match("^Picture[ -]in[ -][Pp]icture$") then hl.dispatch(hl.dsp.window.alter_zorder({ window = p, mode = "top" })) end
  end
end)

-- Shell mode (Oracle's own mission control): shown/hidden by anything (gesture, `oracle shell`, Super+M) -> keys follow it
hl.on("workspace.special_active", function(ws)
  local shown = ws and ws.name == "special:shell"
  if shown then
    if hl.get_current_submap() ~= "shell" then hl.dispatch(hl.dsp.submap("shell")) end
  elseif hl.get_current_submap() == "shell" then
    hl.dispatch(hl.dsp.submap("reset"))
  end
end)

local function app(w) return w and w.class and w.class ~= "" and w.class ~= "oracle.shell" and w.class end

-- Command-`: the next window of the same app
local function same_app()
  local a = hl.get_active_window(); if not app(a) then return end
  local ws = {}
  for _, w in ipairs(hl.get_windows()) do if w.class == a.class then ws[#ws + 1] = w end end
  table.sort(ws, function(x, y) return x.address < y.address end)
  for i, w in ipairs(ws) do
    if w.address == a.address then
      local n = ws[i % #ws + 1]
      hl.dispatch(hl.dsp.focus({ window = n })); hl.dispatch(hl.dsp.window.alter_zorder({ window = n, mode = "top" }))
      return
    end
  end
end

local Mod = "SUPER"
-- macOS-style keys: new binds only, on keys that were free (the old ones stay as they were)
hl.bind(Mod .. " + grave",       same_app)                   -- Command-`
hl.bind(Mod .. " + CTRL + F",    hl.dsp.window.fullscreen({ action = "toggle" })) -- Control-Command-F
hl.bind(Mod .. " + CTRL + Q",    hl.dsp.exec_cmd("loginctl lock-session"))        -- Control-Command-Q (hypridle locks)
hl.bind(Mod .. " + comma",       hl.dsp.exec_cmd("ghostty --class=oracle.settings --gtk-single-instance=false --window-width=70 --window-height=34 -e oracle settings")) -- Command-comma
hl.bind(Mod .. " + ALT + Escape", hl.dsp.exec_cmd("sh -c 'notify-send -a \"Force Quit\" -u low -t 5000 \"Click a window to force quit it\" \"Esc cancels.\"; hyprctl kill'")) -- Option-Command-Esc: click the stuck window (Esc cancels)

-- 4 fingers up = Shell mode rises from the bottom, 4 fingers down sends it back down (Mission Control: the motion follows the fingers).
-- Two one-way gestures, not the native `special` one: that one toggles on the same swipe both ways and rose from the bottom on a swipe DOWN.
local function shell_shown() return hl.get_current_submap() == "shell" end
hl.gesture({ fingers = 4, direction = "up",   action = function() if not shell_shown() then hl.dispatch(hl.dsp.workspace.toggle_special("shell")) end end })
hl.gesture({ fingers = 4, direction = "down", action = function() if shell_shown() then hl.dispatch(hl.dsp.workspace.toggle_special("shell")) end end })
