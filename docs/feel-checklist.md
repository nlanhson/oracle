# Feel: laptop checklist

Back to normal at any time: from Shell mode `oracle try back`, answer y, restart. If `oracle` is broken: `bash ~/.local/state/oracle/try/oracle try back`. Plain login: Ctrl+Alt+F2.

## Already checked (from docs/feel-tuning.md)
- Power button opens the power menu; bar without memory/temperature, power under the Oracle mark; Super+Ctrl+F.
- Launcher sums, dialogs (centred, dimmed), clipboard after an app quits, launcher learns your picks.
- Bar blur, text rendering, two-finger right click, media keys, motion, lock screen (blurred desktop).
- Brave two-finger back/forward, Super+P confirm, key repeat.

## Still to test (most important first)
Pick up the fixes first: `oracle update` (brings airctl and the new bar config without the screen button), then log out and in once so every part has the new settings.

1. Blur: launcher (Signal), Notification Center, banners, volume pop-up, Control Center are all frosted over a busy window.
2. Control Center: right column is Do Not Disturb + a wide Settings tile. Wi-Fi shows your network name; Battery says "Plugged in" when held at the limit and shows "Limit N%", live while you drag (it was left at 20% during the first test; now back at 50%). Click the Wi-Fi name: airctl opens (floating).
3. Now Playing: play something. The card is in the Control Center with a progress bar you can drag; press a media key: a small card drops under the bar for 3 s; click the song name on the bar: the card stays until you click away.
4. Shell mode, four fingers: swipe UP, it rises from the bottom; swipe DOWN, it goes back down. If either feels backwards, say which.
5. Signal: Super+Space shows "Signal" in the field. Super+P, Shut Down: "Shuts down automatically in 60 seconds" counts down; Cancel is first; Enter on Shut Down acts at once.
6. Notification Center: Clear All is plain text and disappears when empty. (The "No Notifications" line still sits mid-screen: known, open.)
7. Super+comma Settings pop-up fits the screen; the list scrolls with the arrow keys.
8. Space in Files: preview opens in a floating window. If you still get Properties, run `nautilus -q`, reopen Files, try again.
9. Super+Alt+Esc: a banner says "Click a window to force quit it", click a window: it closes; Esc cancels.
10. Print, drag an area: a thumbnail banner with Copy / Edit appears (could not reproduce the missing banner here; if it still fails, tell me whether Do Not Disturb was on).
11. Removed, nothing to test: Super+Tab, four-finger pinch, the laptop-screen button.
12. Trackpad and Keyboard rows in Settings change things live (not tested yet).
13. Open the lid after a while closed: the screen comes back at normal brightness.
14. Boot and login: no text on boot, grey menu on tap M, readable login, wrong-password fallback, `oracle doctor` all ok.
    New in this update: the disk keeps unlocking by itself after firmware updates (that was why it asked for the password since October). Nothing to do: `oracle doctor` should say `unlock at boot  TPM, no password`, and a restart should not ask for it.
15. Unplug: dim at 2 min, off at 3; `oracle update --check` count next to `[u]pdate`.
16. Notification cards slide in from the right; lock the screen, send one: it waits in the list.
