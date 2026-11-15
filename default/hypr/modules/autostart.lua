-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function ()
  hl.exec_cmd("systemctl --user set-environment GDK_WAYLAND_DISABLE=ext_background_effect_manager_v1") -- GTK 4 turns blur off by itself; swaync runs as a systemd user unit and needs it in ITS environment
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP &")
  hl.exec_cmd("systemctl --user start hyprpolkitagent") -- Oracle: admin password prompts for desktop apps
  hl.exec_cmd("fcitx5 -d") -- Vietnamese typing (Ctrl+Shift)
  hl.exec_cmd("xsettingsd") -- Oracle: dark theme for older (X11) apps
  hl.exec_cmd("hypridle")
  hl.exec_cmd("swayosd-server &")
  hl.exec_cmd("waybar &")
  hl.exec_cmd("swaync &")
  hl.exec_cmd("qs -p " .. os.getenv("HOME") .. "/.local/share/oracle/default/quickshell &") -- Control Center, started once so it opens at once
  hl.exec_cmd("oracle panel quiet &") -- no banners while locked or screen-sharing
  hl.exec_cmd("oracle launcher daemon") -- Oracle: launcher waits hidden, so Super+Space opens at once
  hl.exec_cmd("udiskie &")
  hl.exec_cmd("wl-clip-persist --clipboard regular") -- Oracle: what you copied stays after the app quits (macOS)
  hl.exec_cmd("oracle shell --hidden") -- Oracle: Shell mode waits out of sight, so the first open is instant
  hl.exec_cmd("oracle pending") -- Oracle: wallpaper (swaybg), night light, a file opened from Shell mode

 end)
