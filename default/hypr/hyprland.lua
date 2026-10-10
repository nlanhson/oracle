-- Oracle defaults. Owned by repo; updates replace it. User edits go in ~/.config/hypr/hyprland.lua.
local O = {}

-- key = action. Actions: exec <cmd> | close | float | exit | dpms | drag | resize
--                        focus <left|right|up|down> | workspace <n|e+1|e-1>
O.binds = {
  ["SUPER + Return"] = "exec ghostty",
  ["SUPER + B"]      = "exec brave-origin",
  ["SUPER + Q"]      = "close",
  ["SUPER + F"]      = "float",
  ["SUPER + M"]      = "exit",
  ["SUPER + O"]      = "dpms",
  ["SUPER + left"]   = "focus left",
  ["SUPER + right"]  = "focus right",
  ["SUPER + up"]     = "focus up",
  ["SUPER + down"]   = "focus down",
  ["SUPER + J"]      = "focus left",
  ["SUPER + L"]      = "focus right",
  ["SUPER + I"]      = "focus up",
  ["SUPER + K"]      = "focus down",
  ["SUPER + 1"]      = "workspace 1",
  ["SUPER + 2"]      = "workspace 2",
  ["SUPER + 3"]      = "workspace 3",
  ["SUPER + 4"]      = "workspace 4",
  ["SUPER + 5"]      = "workspace 5",
  ["SUPER + mouse_down"] = "workspace e+1",
  ["SUPER + mouse_up"]   = "workspace e-1",
  ["SUPER + mouse:272"]  = "drag",
  ["SUPER + mouse:273"]  = "resize",
  ["XF86AudioRaiseVolume"]  = "exec wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+",
  ["XF86AudioLowerVolume"]  = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
  ["XF86AudioMute"]         = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
  ["XF86AudioMicMute"]      = "exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
  ["XF86MonBrightnessUp"]   = "exec brightnessctl -e4 -n2 set 5%+",
  ["XF86MonBrightnessDown"] = "exec brightnessctl -e4 -n2 set 5%-",
}

local function dispatcher(action)
  local verb, arg = action:match("^(%S+)%s*(.*)$")
  if verb == "exec" then return hl.dsp.exec_cmd(arg) end
  if verb == "close" then return hl.dsp.window.close() end
  if verb == "float" then return hl.dsp.window.float({ action = "toggle" }) end
  if verb == "exit" then return hl.dsp.exit() end
  if verb == "dpms" then return hl.dsp.dpms("off") end -- toggles
  if verb == "drag" then return hl.dsp.window.drag(), { mouse = true } end
  if verb == "resize" then return hl.dsp.window.resize(), { mouse = true } end
  if verb == "focus" then return hl.dsp.focus({ direction = arg }) end
  if verb == "workspace" then return hl.dsp.focus({ workspace = tonumber(arg) or arg }) end
  error("oracle: unknown bind action '" .. action .. "'")
end

function O.apply()
  hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
  hl.env("XCURSOR_SIZE", "24")
  hl.env("HYPRCURSOR_SIZE", "24")
  hl.config({
    input = { kb_layout = "us", follow_mouse = 1 },
    misc = { force_default_wallpaper = 0, disable_hyprland_logo = true },
  })
  hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
  end)
  for key, action in pairs(O.binds) do
    if action then
      local d, opts = dispatcher(action)
      if key:match("^XF86") then opts = { locked = true, repeating = true } end
      hl.bind(key, d, opts)
    end
  end
end

return O
