-- Oracle Hyprland defaults: one module per job. Owned by repo; user edits go in ~/.config/hypr/hyprland.lua.
local D = os.getenv("HOME") .. "/.local/share/oracle/default/hypr/"
local O = { binds = dofile(D .. "binds.lua") }

function O.apply()
  for _, m in ipairs({ "env", "look", "input", "autostart" }) do dofile(D .. m .. ".lua") end
  dofile(D .. "keys.lua")(O.binds)
end

return O
