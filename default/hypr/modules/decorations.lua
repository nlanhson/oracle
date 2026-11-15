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
            range        = 48, -- wide and soft, like the reference: depth without a dark outline
            render_power = 2,
            offset       = "0 16",
            color        = 0x66000000,
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

-- Frosted surfaces: blur behind the dark tint. ignore_alpha keeps the see-through corners and gaps unblurred.
-- ONE rule per namespace: a second rule for the same namespace replaces the first one's blur (found on the laptop).
-- animation: Control Center (Quickshell) and launcher fade/appear themselves; the volume pop-up fades; notification cards slide in from the right, where they live (as on macOS Sequoia)
local frosted = {
    { "waybar" },
    { "launcher",                    "none" },
    { "oracle-panel",                "none" },
    { "oracle-media",                "none" },
    { "swaync-control-center" },
    { "swaync-notification-window",  "slide right" },
    { "swayosd",                     "fade" },
}
for _, f in ipairs(frosted) do
    local rule = { match = { namespace = "^(" .. f[1] .. ")$" }, blur = true, ignore_alpha = f[1] == "waybar" and 0.2 or 0.5 } -- 0.5: the soft shadows (alpha < 0.5) are not frosted, only the panel itself
    if f[2] == "none" then rule.no_anim = true elseif f[2] then rule.animation = f[2] end
    hl.layer_rule(rule)
end
