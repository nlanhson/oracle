-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 0,
        gaps_out = 0,

        border_size = 1,

        col = {
            active_border   = { colors = {"rgb(c8c8c8)"}},
            inactive_border = "rgb(252525)",
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,
    },

    decoration = {
        rounding       = 8,
        rounding_power = 4, -- Squircle

        active_opacity   = 1.0,
        inactive_opacity = 0.9,

        shadow = {
            enabled      = false,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = true,
            size      = 6,
            passes    = 3,
            vibrancy  = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Blur
hl.layer_rule({
    match         = { namespace = "^(waybar)$" },
    blur          = true,
    ignore_alpha  = 0.1
})

-- Fuzzel
hl.layer_rule({	
    match        = { namespace = "^(fuzzel)$" },
    animation    = "none",
    no_anim      = true
})

hl.layer_rule({
    match        = { namespace = "^(fuzzel)$" },
    blur         = true,
    ignore_alpha = 0.1
})
