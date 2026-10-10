-- oracle-user-config: yours. Updates never touch this file.
local O = dofile(os.getenv("HOME") .. "/.local/share/oracle/default/hypr/hyprland.lua")

-- Change or remove binds before apply. Examples:
-- O.binds["SUPER + B"] = "exec firefox"
-- O.binds["SUPER + O"] = false

O.apply()

-- Extra Hyprland settings after apply.
