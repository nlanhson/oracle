-- Oracle Hyprland defaults = owner's config (config/*.lua). Owned by repo; your changes go in ~/.config/hypr/hyprland.lua.
local D = os.getenv("HOME") .. "/.local/share/oracle/default/hypr/"
package.path = D .. "?.lua;" .. os.getenv("HOME") .. "/.config/hypr/?.lua;" .. package.path

for _, m in ipairs({ "animations", "autostart", "colors", "decorations", "variables", "environment", "inputs",
                     "binds", "misc", "monitors", "windowrules", "workspaces" }) do
  require("config." .. m)
end

-- Oracle: open what `oracle open` asked for from Shell mode
hl.on("hyprland.start", function() hl.exec_cmd("oracle pending") end)

-- Noctalia color template (~/.config/hypr/noctalia.lua), if Noctalia has written one
local ok, noctalia = pcall(require, "noctalia")
if ok then noctalia.apply_theme() end

return { binds = {}, apply = function() end } -- old user files call O.apply()
