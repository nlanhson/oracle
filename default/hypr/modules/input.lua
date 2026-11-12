---------------
---- INPUT ----
---------------

local S = require("modules.settings")

hl.config({
    input = {
        kb_layout  = "us",

        follow_mouse = 1, -- focus follows the pointer (owner's choice, kept)

        sensitivity = tonumber(S.tracking) or 0.37, -- -1.0 - 1.0, 0 means no modification. Settings: Trackpad > tracking speed

        touchpad = {
            natural_scroll = S.natural ~= "off", -- Settings: Trackpad > natural scrolling
            tap_to_click = S.tap ~= "off", -- Settings: Trackpad > tap to click
            clickfinger_behavior = true, -- macOS: two-finger click = right click, three = middle (no corner zones)
            disable_while_typing = true, -- palm is ignored while typing
            middle_button_emulation = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})
