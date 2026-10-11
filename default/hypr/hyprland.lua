-- Oracle Hyprland defaults = owner's config (config/*.lua). Owned by repo; your changes go in ~/.config/hypr/hyprland.lua.
local D = os.getenv("HOME") .. "/.local/share/oracle/default/hypr/"
package.path = D .. "?.lua;" .. os.getenv("HOME") .. "/.config/hypr/?.lua;" .. package.path

for _, m in ipairs({ "animations", "autostart", "colors", "decorations", "variables", "environment", "inputs",
                     "binds", "misc", "monitors", "windowrules", "workspaces" }) do
  require("config." .. m)
end

-- Oracle settings screen (~/.config/oracle/settings): screen scale, keyboard layout
local S = {}
local f = io.open(os.getenv("HOME") .. "/.config/oracle/settings")
if f then
  for l in f:lines() do local k, v = l:match("^([%w_]+)=(.*)$"); if k then S[k] = v end end
  f:close()
end
if S.scale then hl.monitor({ output = MONITOR1, mode = "preferred", position = "auto", scale = S.scale }) end
if S.keyboard then hl.config({ input = { kb_layout = S.keyboard } }) end

-- Oracle: night light, wallpaper picked in Shell mode, file `oracle open` asked for
hl.on("hyprland.start", function() hl.exec_cmd("oracle pending") end)

-- Noctalia color template (~/.config/hypr/noctalia.lua), if Noctalia has written one
local ok, noctalia = pcall(require, "noctalia")
if ok then noctalia.apply_theme() end

return { binds = {}, apply = function() end } -- old user files call O.apply()
