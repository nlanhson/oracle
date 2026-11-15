----------------
---- MOTION ----
----------------
-- Oracle Feel, slice 1 (docs/feel.md): motion explains where things come from and go, then gets out of the way.
-- speed = length in 0.1 s. Entrances ease out, exits are shorter and ease in, nothing runs past 0.35 s.

-- settle: spring just under critical damping (0.9), so things arrive with a little life but never bounce
hl.curve("settle", { type = "spring", mass = 1, stiffness = 240, damping = 28 })
hl.curve("enter",  { type = "bezier", points = { {0.22, 1}, {0.36, 1} } }) -- fast start, soft landing
hl.curve("leave",  { type = "bezier", points = { {0.4, 0},  {1, 1}    } }) -- gets out of the way
hl.curve("glide",  { type = "bezier", points = { {0.3, 0},  {0.1, 1}  } }) -- both ends soft, for whole-screen moves

hl.animation({ leaf = "global",        enabled = true, speed = 2,   bezier = "enter" })

-- Windows grow from their own place, shrink back into it, and glide when the layout changes
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 2.5, spring = "settle", style = "popin 92%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.5, bezier = "leave",  style = "popin 94%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 2.5, spring = "settle" })

hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.5, bezier = "enter" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.2, bezier = "leave" })
hl.animation({ leaf = "fadeSwitch",    enabled = true, speed = 1.5, bezier = "enter" }) -- the window in use steps forward
hl.animation({ leaf = "fadeDpms",      enabled = true, speed = 3,   bezier = "glide" }) -- screen off / on
hl.animation({ leaf = "border",        enabled = true, speed = 1.5, bezier = "enter" })

-- Panels and notifications slide from their own edge
hl.animation({ leaf = "layersIn",      enabled = true, speed = 2,   bezier = "enter", style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5, bezier = "leave", style = "slide" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.2, bezier = "enter" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1,   bezier = "leave" })
hl.animation({ leaf = "fadePopups",    enabled = true, speed = 1,   bezier = "enter" }) -- menus

-- Workspaces move the way the fingers move. Shell mode rises over the desktop
hl.animation({ leaf = "workspaces",       enabled = true, speed = 3,   bezier = "glide", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.5, bezier = "glide", style = "slidefadevert 12%" })
hl.animation({ leaf = "zoomFactor",       enabled = true, speed = 2.5, bezier = "glide" })

-- Layer rules (blur + per-surface animation, one rule per namespace) live in decorations.lua

-- Touchpad. 3 fingers sideways = workspaces (input.lua). A short flick is enough to switch.
hl.config({ gestures = { workspace_swipe_cancel_ratio = 0.3, workspace_swipe_create_new = false } })
hl.gesture({ fingers = 2, direction = "pinch", mods = "SUPER", action = "cursor_zoom", zoom_level = 1, mode = "live" }) -- Super + pinch = zoom in on the pointer
