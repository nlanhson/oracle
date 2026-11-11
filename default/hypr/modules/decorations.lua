-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/

-- Oracle look tokens (default/look/tokens → `oracle look` → ~/.config/oracle/look/tokens.lua). Missing file = today's values.
local T = (loadfile(os.getenv("HOME") .. "/.config/oracle/look/tokens.lua") or function() return {} end)()

hl.config({
    general = {
        gaps_in  = 0,
        gaps_out = 0,

        border_size = T.border or 1,

        col = {
            active_border   = { colors = {"rgb(" .. (T.accent or "c8c8c8") .. ")"}},
            inactive_border = "rgb(" .. (T.line or "3a3a3a") .. ")",
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,
    },

    decoration = {
        rounding       = T.r_m or 8,
        rounding_power = 4, -- Squircle

        active_opacity   = 1.0,
        inactive_opacity = 0.9,

        -- Shadow only under floating windows (rule below); tiled windows have none
        shadow = {
            enabled      = true,
            range        = 24,
            render_power = 3,
            offset       = "0 8",
            color        = 0x99000000,
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

-- Tiled windows: no shadow
hl.window_rule({ name = "oracle-no-shadow-tiled", match = { float = false }, no_shadow = true })

-- Frosted surfaces: blur behind the dark tint. ignore_alpha keeps the see-through corners and gaps unblurred
for _, ns in ipairs({ "waybar", "launcher", "swaync-control-center", "swaync-notification-window", "swayosd" }) do
    hl.layer_rule({ match = { namespace = "^(" .. ns .. ")$" }, blur = true, ignore_alpha = 0.2 })
end

-- Launcher (namespace "launcher"): appears at once
hl.layer_rule({
    match        = { namespace = "^launcher$" },
    animation    = "none",
    no_anim      = true
})
