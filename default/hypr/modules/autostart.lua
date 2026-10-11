-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function ()
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP &")
  hl.exec_cmd("systemctl --user start hyprpolkitagent") -- Oracle: admin password prompts for desktop apps
  hl.exec_cmd("hypridle")
  hl.exec_cmd("swayosd-server &")
  hl.exec_cmd("waybar &")
  hl.exec_cmd("swaync &")
  hl.exec_cmd("udiskie &")
  hl.exec_cmd("oracle pending") -- Oracle: wallpaper (swaybg), night light, a file opened from Shell mode

 end)
