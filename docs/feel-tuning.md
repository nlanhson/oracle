# Feel: tuning list from the laptop check (2026-11-12, preview on the G14)

Status after the tuning round: FIXED = done and seen on the real desktop (screenshots in the helper's notes), OPEN = still to do.

1. FIXED Blur missing. Two causes. (a) GTK 4 switches blur off by itself (ext-background-effect protocol): launcher, swaync and swayosd are GTK 4, the bar is GTK 3 and Quickshell is Qt, so those two were fine. Fix: `GDK_WAYLAND_DISABLE=ext_background_effect_manager_v1` (env.lua; `systemctl --user set-environment` for the swaync unit; set inside bin/oracle-launcher). (b) Each of launcher, panel, swaync notifications and swayosd had two layer rules; the second replaced the first one's blur. Now ONE rule per namespace (decorations.lua). Also ignore_alpha 0.5 so soft shadows are not frosted.
2. OPEN, not reproduced. `oracle shot` works on the real desktop in region, screen and window modes, started from Hyprland like the key does: the banner with Copy / Edit shows. Likely the owner had Do Not Disturb on, or the swaync of that moment had no blur and the banner was hard to see. Re-test.
3. FIXED. Sushi works (`org.gnome.NautilusPreviewer2` activates, Space in a real Files window opens the preview). It opened as a tiled window: now a floating window rule. If Space still shows Properties: `nautilus -q`, reopen Files (Files started before sushi was installed).
4. FIXED. Super+Alt+Esc shows "Click a window to force quit it / Esc cancels." then `hyprctl kill`. Bind registered; the click itself was not exercised (no way to inject a click here).
5. FIXED, to re-test by hand. Two one-way gestures: 4 fingers UP opens Shell mode (rises from the bottom), 4 fingers DOWN closes it. Not 1:1 with the fingers any more (the gesture fires when the swipe ends); the old native `special` gesture toggled on the same swipe both ways.
6. FIXED. (a) pinch gesture removed. (b) Super+Tab removed (bind, code, vm test, manual, checklist). (c) Laptop-screen control removed from the bar config, bar CSS, Control Center and `oracle panel`; migration 1794500000 swaps an untouched previous bar config. Control Center right column = Do Not Disturb + one wide Settings tile.
7. FIXED. Battery title row reads "22% · On battery · Limit 20%", live while dragging.
8. PARTLY. Clear All is plain muted text, brighter on hover, hidden when empty. The "No Notifications" line still sits mid-screen (swaync centres it in the full-height list; CSS margin tricks did not move it reliably; needs a config change `vexpand: false` plus a different layout). Judgement call, left as is.
9. FIXED. Restart / Shut Down confirm counts down ("Shuts down automatically in 60 seconds"), goes ahead at zero, Cancel is the default, Enter on Shut Down acts at once. Tested with a stub (`ORACLE_LAUNCHER_DRY`, `ORACLE_LAUNCHER_COUNTDOWN`).
10. FIXED. Now Playing: `default/quickshell/NowPlaying.qml` in the Control Center, an `oracle-media` pop-up (3 s after a media key, or kept by clicking the song name on the bar), `oracle panel media [key]`. Progress bar only if the player can seek. Tested with a fake MPRIS player (reads, pause, track change); dragging the bar was not exercised (no way to inject a drag).
11. FIXED. Settings pop-up is sized to the screen (60% x 88%) and the list scrolls inside it.
12. FIXED. Launcher name = "Signal" (placeholder; `NAME` in bin/oracle-launcher is the one place; command stays `oracle launcher`).
13. Wi-Fi row opens `airctl` (AUR `airctl-bin`, GTK 4 + NetworkManager, GPL-3.0) when installed, floating; otherwise the terminal list.
14. Nothing of Oracle's uses three fingers vertically (the owner removed his own 3-finger-up fullscreen; 3-finger-down = close stays his).
15. Judgement calls: the volume pop-up speaker glyph is large; waybar's mpris item stays visible while paused.
