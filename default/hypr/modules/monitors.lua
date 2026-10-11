------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "1920x0",
    scale    = "1.67",
})

hl.monitor({
    output   = "HDMI-A-1",
    mode     = "preferred",
    position = "0x0",
    scale    = "1",
})

-- Workspaces 1-5 on main monitor
hl.workspace_rule({ workspace = "1", monitor = "eDP-1", persistent = true})
hl.workspace_rule({ workspace = "2", monitor = "eDP-1", persistent = true})
hl.workspace_rule({ workspace = "3", monitor = "eDP-1", persistent = true})
hl.workspace_rule({ workspace = "4", monitor = "eDP-1", persistent = true})
hl.workspace_rule({ workspace = "5", monitor = "eDP-1", persistent = true})

hl.workspace_rule({ workspace = "6", monitor = "HDMI-A-1", persistent = true})
hl.workspace_rule({ workspace = "7", monitor = "HDMI-A-1", persistent = true})
hl.workspace_rule({ workspace = "8", monitor = "HDMI-A-1", persistent = true})
hl.workspace_rule({ workspace = "9", monitor = "HDMI-A-1", persistent = true})
hl.workspace_rule({ workspace = "10", monitor = "HDMI-A-1", persistent = true})