-- Oracle Hyprland defaults = owner's dotfiles (modules/*.lua). Owned by repo; your changes go in ~/.config/hypr/hyprland.lua.
local D = os.getenv("HOME") .. "/.local/share/oracle/default/hypr/"
package.path = D .. "?.lua;" .. os.getenv("HOME") .. "/.config/hypr/?.lua;" .. package.path

for _, m in ipairs({ "monitors", "autostart", "binds", "env", "decorations", "motion", "layout", "misc", "input", "behaviour", "windowrules" }) do
  require("modules." .. m)
end

-- G14: draw the desktop on the AMD chip (udev rule 61-oracle-amd-igpu.rules), the NVIDIA one stays asleep
if io.open("/dev/dri/amd-igpu") then hl.env("AQ_DRM_DEVICES", "/dev/dri/amd-igpu") end

-- Vietnamese typing (fcitx5 + bamboo), desktop only: Shell mode never sets these. No GTK_IM_MODULE: GTK uses the Wayland input method
for k, v in pairs({ QT_IM_MODULE = "fcitx", XMODIFIERS = "@im=fcitx", SDL_IM_MODULE = "fcitx", GLFW_IM_MODULE = "ibus" }) do
  hl.env(k, v)
end

-- Oracle settings screen (~/.config/oracle/settings): screen scale, keyboard layout (the rest is read in input.lua / behaviour.lua)
local S = require("modules.settings")
if S.scale then hl.monitor({ output = "eDP-1", mode = "preferred", position = "1920x0", scale = S.scale }) end
if S.keyboard then hl.config({ input = { kb_layout = S.keyboard } }) end

return { binds = {}, apply = function() end } -- old user files call O.apply()
