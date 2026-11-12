# Feel: laptop checklist

Everything in `docs/feel.md` is built and passes the full VM install (200 checks). This list is what a VM cannot judge.
Work through it on the G14, note what feels off in plain words, and say which items to tune or drop.

## Before you start

1. Fix the disk prompt first (once): `sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme0n1p2`, restart, no disk prompt.
2. `oracle update` (brings the `oracle try` command), then `oracle try feel/try`, answer y, wait, restart.
3. To go back at any time: from Shell mode run `oracle try back`, answer y, restart at once.
   If `oracle` itself is broken: `bash ~/.local/state/oracle/try/oracle try back`.
4. If the login screen misbehaves: Ctrl+Alt+F2 gives a plain login.

## What is different from what you are used to

| Change | Switch it back |
|---|---|
| Power button opens the power menu instead of shutting down (hold 5 s = off) | drop-in `zz-mine.conf` with `HandlePowerKey=poweroff` in `/etc/systemd/logind.conf.d/` |
| Battery: notices at 20% and 10%, clean shutdown at 4% | `sudo systemctl mask --now oracle-power.service` |
| Alerts and the weekly update notice | `systemctl --user mask --now oracle-watch.timer` |
| Screen dims at 2 min and turns off at 3 min on battery (5 and 7 plugged in) | edit `~/.config/hypr/hypridle.conf` |
| Key repeat is faster | Settings → Keyboard → key repeat: slow |
| Two-finger click is right click; touchpad corners do nothing special | `clickfinger_behavior = false` in your `~/.config/hypr/hyprland.lua` |
| Three fingers up/down = Shell mode (was: nothing) | tell me |
| Bar: no memory, temperature or power button; power menu is under the Oracle mark | tell me |
| Launcher is Oracle's own, fuzzel is no longer used | tell me |
| Boot menu is hidden: tap M in the first second to open it | set `timeout: 5` in `/boot/limine.conf` |
| New keys: Super+Tab, Super+`, Super+Ctrl+F, Super+Ctrl+Q, Super+comma, Super+Alt+Esc, Super+Shift+3/4/5, media keys | tell me which to drop |

## Check

**Boot and login**
- [ ] Power on, touch nothing: no text, no menu, straight to the ORACLE login. Does the ASUS logo hold, or does the screen go black in between?
- [ ] Tap M from the power button: the grey menu opens, Snapshots are listed.
- [ ] Login screen readable on your display. Type a wrong password once: is the plain "Login incorrect" fallback acceptable?
- [ ] `oracle doctor`: every line ok.

**Look**
- [ ] Bar: Oracle mark, app name in bold, icons, date and time. Size right at your 1.67 scale? Battery shows as % plus icon.
- [ ] Frosted blur on bar, Control Center, launcher, notifications, volume pop-up: readable on the dunes and on a bright wallpaper?
- [ ] Text: as crisp as before, or softer? (New rendering rules; easy to revert.)
- [ ] Lock (`Super + Ctrl + Q`): blurred desktop behind the clock, or plain black?
- [ ] Folder icons grey in Files. Floating windows have a soft shadow.

**Motion**
- [ ] Open and close a terminal a few times: quick and soft, no pop, no bounce.
- [ ] Three windows, close the middle one: the others glide.
- [ ] Workspaces by three-finger swipe (slow and flick) and Super+1–5.

**Control Center and notifications**
- [ ] Bar icon opens it at once, 6 px under the bar; Esc and a click outside close it.
- [ ] Wi-Fi shows your network name, Bluetooth your device; the round buttons toggle; clicking the text opens the list.
- [ ] Display and Sound sliders follow the drag with no lag; brightness never goes black. Battery slider changes the charge limit.
- [ ] Do Not Disturb: the panel and the bar icon agree. (In the VM the bar showed the bell while the panel said Off.)
- [ ] Click the date: notification cards float on the right. Send yourself a few; 5 seconds feels right? Lock the screen, send one: nothing pops up, it waits in the list.
- [ ] Memory: `ps -o rss= -C qs` (it sat near 189 MB in the VM).

**Launcher**
- [ ] Super+Space: appears with no delay, typing lands at once. Vietnamese typing works in it.
- [ ] `12*7`, Enter, paste: 84. A file from Documents opens. An `oracle` command runs.
- [ ] Open the same app by two letters a few times: it becomes the first result.
- [ ] Super+P → Shut Down: asks, Cancel is first. Lock acts at once.

**Behaviour**
- [ ] Super+Tab walks through every open app and comes round again.
- [ ] Super+` moves between two windows of one app. Super+Ctrl+F full screen. Super+comma opens Settings.
- [ ] Three fingers up/down: Shell mode follows your fingers; Super+M still works both ways.
- [ ] Four-finger pinch opens the launcher. Super+pinch zooms.
- [ ] Two-finger click = right click. Brave Origin: two-finger swipe goes back and forward.
- [ ] A file picker and a password prompt float in the centre with the rest dimmed. Picture-in-picture stays in the corner.
- [ ] Copy text, quit the app, paste: still there. Space in Files previews a file.
- [ ] Play/pause/next keys. Shift+Alt+volume takes small steps.
- [ ] Super+Alt+Esc, click a window: it closes. Esc cancels.
- [ ] Settings → Trackpad and Keyboard rows change things live.

**Screenshots**
- [ ] Print, drag, paste into a chat: under 3 seconds. Esc leaves nothing.
- [ ] The thumbnail: Copy, Edit (opens the editor), click = open the picture.

**System**
- [ ] Tap the power button on the desktop: power menu. In Shell mode: nothing. 
- [ ] Unplug: screen dims at 2 min, off at 3, keyboard light goes with it. A playing video keeps it on.
- [ ] `oracle update --check`: a count next to `[u]pdate`; the dashboard still fits your screen.

**Not for this round**
- Secure Boot (`oracle secureboot`): leave it off until the rest feels right. Its own page: `docs/manual/secure-boot.md`.
- `oracle welcome`: run it by hand once if you want to see the first-run guide.
