# Oracle Feel

The plan for making Oracle feel as considered as macOS: calm, consistent, smooth, nothing rough.
We learn *why* macOS feels good and apply that thinking in Oracle's own monochrome Batcomputer style.
We do not copy it: no Apple code, fonts, icons, sounds or wallpapers.

Sources: Apple's Human Interface Guidelines, WWDC design talks ("Designing Fluid Interfaces",
"Essential Design Principles"), public design writing, and watching how the system behaves.

## Ground rules

- **One reference: macOS Sequoia (15).** When a choice is open (how tall the bar is, how a panel is laid out, where a
  notification sits, how long something takes to move), we do what Sequoia does, in Oracle's greys. It is the last
  macOS with the frosted look, before Liquid Glass. A guide for layout, proportion and behaviour, never a source of assets.
- Shell mode stays pure Oracle. The desktop (Hyprland) may borrow macOS *patterns* where they fit.
- Existing keys never change without asking. New features get keys that fit the current scheme.
- Monochrome: greys and white, muted red only for errors.
- Frosted, not liquid: see-through surfaces with a soft blur are welcome on the bar, panels, launcher,
  notifications and lock screen. No refraction, lensing or wobbly highlights. Windows stay solid.
- Text stays crisp on any wallpaper: every frosted surface keeps a dark tint strong enough for
  4.5:1 contrast, checked against a white and a busy wallpaper.
- Light and fast like plain Arch. Every new package has to earn its place.
- Choices already made stay as they are (terminal opacity, no gaps between windows, no lock at start,
  the machine never sleeps by itself because it is also the server).

## Principles

| # | What macOS teaches | What it means for Oracle |
|---|---|---|
| 1 | **Motion explains.** Animation shows where a thing came from and where it went. It is short, springy, and can be interrupted. | Windows grow from where they open and shrink back. Panels slide from their own edge. Workspaces move the way your fingers move. 150 to 350 ms, never longer. Typing is never delayed by an animation. |
| 2 | **One visual language.** The same shapes, spacing, greys and type everywhere, so nothing looks like a different program. | One file of tokens (colour, type, spacing, corner radius, cursor, icons). The bar, launcher, notifications, lock screen and apps all read from it. Today the same greys are typed out in 7 files. |
| 3 | **Quiet by default.** Content first. The system speaks only when it needs you. | The bar shows a few things, small. Notifications are grouped and silent unless they matter. No boot text, no pop-ups you did not ask for. |
| 4 | **Depth shows hierarchy.** A few clear layers. Material and shadow say "this sits above that". | Four layers: wallpaper, windows, panels, alerts. Frosted material only on things that come and go. The window in use is obvious, the rest step back. Shadows only under floating windows. |
| 5 | **Direct and instant.** Things respond within a tenth of a second and follow the finger. | Touchpad gestures track 1:1. Volume and brightness show at once. The launcher is ready the moment it appears. |
| 6 | **Forgiving.** Undo beats "are you sure?". Only destructive things ask. | Rollback and trash already work this way. Keep it: screenshots are kept, closing is safe, only shutdown and wipe confirm. |
| 7 | **Plain words.** An error says what happened and what to do next. | The `oracle doctor` style everywhere: one line of what is wrong, one line of how to fix it, one button if there is a fix. |
| 8 | **Same place, same key, every time.** | Status and controls live top right. Super+Space finds anything. Esc always closes. Keys never move. |

## Touchpoints

| Area | Today | Target | How we test |
|---|---|---|---|
| Windows | Open, close and fade are switched off. Workspaces slide. Only one gesture (3 fingers sideways). | Open, close, move and fade with tuned springs. Gestures for workspaces and Shell mode. | VM: config loads with no errors. G14: feel checklist. |
| Colours and shapes | Greys repeated per app. Corners 8 on windows, 18 on the launcher. Default cursor. | One token file feeds everything. One corner scale, one spacing grid, one cursor. | VM screenshots of every surface side by side. |
| Type | JetBrains Mono everywhere, sizes picked per app. | Inter on the desktop (modern, easy to read, Vietnamese). JetBrains Mono stays in the terminal and Shell mode. One size and weight scale. | Screenshots. |
| Top bar | Text modules, read only. Tray off. Power button. | Same bar, calmer. The control-centre icon opens the Control Center, the clock the Notification Center. | Screenshots, click test. |
| Control Center | None. Wi-Fi and Bluetooth need the Settings screen. | Quickshell panel laid out like Sequoia: round toggles with a subtitle, labelled sliders, battery limit, now playing. Deeper settings open `oracle settings`. | Pixel compare with the Sequoia reference, VM: each control changes the real setting. |
| Notification Center | Stock look in grey. Not grouped. | swaync only: frosted cards float on the desktop (no panel), grouped per app, quiet by default, one clear action. | VM: send test notifications, screenshot. |
| Launcher | Apps only. | One box: apps, files, sums, `oracle` commands, ranked. Still Super+Space. | VM: scripted searches, screenshot. |
| Lock screen | Black, clock, password box. Only on demand. | Frosted view of the desktop, same tokens. Still only on demand. | VM screenshot. |
| Boot | Boot menu every time, scrolling text, text login. | Silent boot with the Oracle mark. Menu only when a key is held. A styled login. Still no autologin. | VM: screenshots every second from power on to desktop, boot time measured. |
| Screenshots | Print = pick an area, saved to a folder. | Pick, then a small thumbnail: click to copy or edit, ignore to keep. | VM: take one, check file and clipboard. |
| System | Updates, lid and battery work. Errors show as raw text. | Boot time measured and cut. Problems arrive as plain-word notifications with a fix. `oracle doctor` covers every new part. | `systemd-analyze` before and after, doctor run in VM. |
| First run | Installer ends at a login prompt. | `oracle welcome`: a short first-run guide (Wi-Fi, wallpaper, accent, keys to know). | VM: fresh install to welcome screen. |

## Behaviour: the layers under the look

Looking like macOS is the thin part. It feels considered because of rules you never see: what gets focus, what a key
always means, what happens when the battery runs low or an app hangs. This is how Sequoia behaves, and what Oracle does
about it. Each line is a real default from Apple's documentation or System Settings, not a guess.

| Layer | What Sequoia does | What Oracle does |
|---|---|---|
| Focus | You click a window to use it. Scrolling goes to whatever is under the pointer, without stealing focus. | Focus follows the pointer (the owner's choice, kept). Scrolling goes to whatever is under the pointer. |
| Apps come forward | Open a link or a file and that app comes to the front, on its own Space if needed. | An app that asks for attention is brought forward, and you are taken to its workspace. |
| Dialogs | Open, Save and password dialogs are small sheets on top of their window, centred, with the rest dimmed. | Dialogs, file pickers, password prompts and small tools float in the centre, never tiled, with the rest dimmed. |
| Picture in picture | A small video stays on top in a corner, on every Space. | Same for the browser's picture-in-picture window. |
| A hung app | "Application Not Responding", with Force Quit. Option-Command-Esc force quits. | The not-responding dialog is on. `Super + Alt + Esc`, then click a window, force quits it. |
| Pointer | Hides while you type, comes back when you move. | Same. |
| Trackpad | Two-finger click is the right click. Two-finger swipe goes back and forward in the browser. Palm is ignored while typing. | Same three. Tap to click stays on. |
| Gestures | Three fingers sideways: Spaces. Up: Mission Control. Pinch with four: apps. | Sideways: workspaces. Four fingers up and down: Shell mode, Oracle's own mission control, following your fingers. Pinch with four: launcher. |
| Keys | Command-Tab: last app. Command-`: next window of this app. Control-Command-F: full screen. Control-Command-Q: lock. Command-comma: settings. Shift-Command-3/4/5: screenshots. | The same on `Super`, only on keys that were free. No existing key changes. `Super + Tab` is simpler than the Mac's: each press goes to the next open app, through all of them. |
| Media keys | Play, next, previous work everywhere. | Same (they did nothing before). |
| Key repeat | Starts after a short pause, then steady. | Tuned to match (shorter pause, even rate). Changeable in Settings. |
| Clipboard | What you copied stays after the app quits. | Same (on Linux it normally vanishes). |
| Quick Look | Space in Finder previews a file. | Space in Files previews a file. |
| Text | Smooth, slightly bold letters, no pixel snapping. | Same rendering rules for the desktop. |
| Screenshots | Named "Screenshot 2026-11-11 at 2.36.12 PM". | Same name. |
| Power button | A press never shuts the Mac down. Hold to force off. | A press opens the power menu. Hold forces off. (Before: one press shut the server down.) |
| Shut down | Restart and Shut Down ask once. Lock and sleep do not. | Same. |
| Battery | Screen dims and sleeps sooner on battery. Warning at 10%. Saves itself before it dies. | Shorter screen timers on battery. Warning at 20% and 10%. Clean shutdown at 4% so the server's data is safe. |
| Idle | Screen off, keyboard light off. A playing video keeps it awake. | Same. The machine itself never sleeps (it is the server). |
| Updates | Checks quietly, tells you, never installs behind your back. | A weekly quiet check, one notice, `oracle update` stays your decision. |
| When things break | "Brave quit unexpectedly." "Your disk is almost full." Plain words, one action. | Same: crash, full disk, failed service and sign-in Wi-Fi pages become one plain notification each. |
| Settings | One place, grouped: Trackpad, Keyboard, Displays, Battery, Lock Screen. | `oracle settings` gains Trackpad, Keyboard and Energy groups with the same names. |

What we leave out, and why: the menu bar's File / Edit menus (Linux apps keep their own), Mission Control's window
overview and Stage Manager (no solid equivalent yet), automatic sleep (this machine is a server), Handoff and other
Apple-account features.

## How a slice ships

1. One branch per slice, `feel/<name>`. `main` always installs and updates cleanly.
2. Built, then tested in the VM (`test/vm.sh`, `test/shot.sh`), screenshots checked against this page.
3. Feel check on the G14 with a 3 to 5 item list. To try a branch:
   `git -C ~/.local/share/oracle switch feel/<name>`, then `hyprctl reload` (or log out and in),
   then `switch main` to go back.
4. One line in the README or manual if users will see it. Then merge.

Feel lives in `default/`, which Oracle loads live, so `oracle update` delivers it. The files in
`~/.config` stay yours and only import the shared look. The first look slice adds that one import line
to your existing copies, after you say yes.

Motion cannot be judged in the VM (no GPU, no touchpad). There the VM only proves the config is valid.
The feel check on the G14 is the real test.

## Slices

Ranked by value for effort. Each ends fully done or is not merged.

| # | Slice | Size | Risk | Done looks like |
|---|---|---|---|---|
| 1 | **Motion.** Springs and timings for windows, layers, workspaces, fades. Touchpad gestures. | S | Low | Nothing pops or snaps. Nothing feels slow. One file, values written down with the reason. |
| 2 | **One look.** Token file, applied to bar, launcher, notifications, lock screen, OSD, borders, GTK apps, cursor. | M | Low | One edit changes a grey everywhere. All surfaces share corners, spacing and frosted material. Text passes contrast on a white wallpaper. |
| 3 | **Control panel and notifications.** Built on swaync, which is already installed. Deeper settings reuse `oracle settings` in a pop-up. | M | Low | Every daily control within two clicks of the bar. Notifications grouped and quiet. No new package. |
| 4 | **Launcher.** One box for apps, files, sums and `oracle` commands. | M | Medium | The top result is right for 20 scripted searches. Opens instantly. Power menu still works. |
| 5 | **Boot to desktop.** Silent boot, menu on keypress, styled login. | M | Medium | Power button to login with no scrolling text. Snapshot menu still reachable. Password fallback readable if the TPM fails. |
| 6 | **Screenshot flow.** Area pick, thumbnail, copy or edit. | S | Low | Print, drag, paste into a chat in under 3 seconds. |
| 7 | **System logic.** Power button, battery rules, idle by power source, quiet update check, plain-word alerts (battery, disk, crash, failed service, sign-in Wi-Fi), boot time, doctor. | M | Medium | A power-button press cannot kill the server. Every alert has a fix line. Boot time written here. |
| 8 | **Welcome.** `oracle welcome` and installer polish. | M | Low | A fresh install ends in a guided first minute. |
| 9 | **Secure Boot and UKI.** Own keys, closes the disk-unlock gap. | L | High | Boots unattended with Secure Boot on, with a tested way back. Or not merged. |
| 10 | **Behaviour.** Focus, dialogs, keys, gestures, clipboard, Quick Look, text rendering, Settings groups (table above). | L | Medium | Every row of the Behaviour table is either checked in the VM or on the laptop checklist. |

Changes from the first ranking, and why:

- **Motion moved to first.** It is the smallest slice and the one you feel most, since window
  animations are off today. It also proves the branch, VM, G14 loop on something low risk.
- **Control panel moved above the launcher.** The launcher already does its main job. The desktop has
  no quick way to change Wi-Fi or Bluetooth at all.
- **Lock screen folded into One look.** It is one more surface reading the tokens, not a boot job.
- **Boot split from the lock screen and kept package-light.** Silent boot first with kernel and Limine
  settings only. A boot splash package is added only if the gap still looks rough.

Open choices are made inside their slice and shown to you before building: the launcher program
(slice 4), the login screen (slice 5), the screenshot editor (slice 6).

## Status

| Slice | State |
|---|---|
| 0 Spec | Done 2026-11-11 |
| 1 Motion | Built on `feel/motion`, waiting for the feel check on the G14 |
| 2 One look | Built on `feel/look`, waiting for the feel check |
| 3 Control Center | Rebuilt with Quickshell (`feel/cc`), waiting for feel check. Notification Center = swaync only |
| 4 Launcher | Built on `feel/launcher` (stacked on `feel/look`), waiting for the feel check. Own small GTK4 program, fuzzel removed |
| 5 Boot to desktop | Built, waiting for feel check (branch `feel/boot`) |
| 6 Screenshot flow | Built on `feel/shot`, waiting for feel check. Editor: satty |
| 7 System logic | Built on `feel/system`, waiting for feel check. Power button, battery rules, idle by power source, quiet update check, plain-word alerts, doctor lines. Boot time measured below |
| 8 Welcome | Built on `feel/welcome`, waiting for feel check |
| 9 Secure Boot + UKI | Built, VM-proven, opt-in: owner switches it on (`oracle secureboot setup`, docs/manual/secure-boot.md). No UKI: Limine checks kernel, initramfs and cmdline by hash instead |
| 10 Behaviour | Built on `feel/behaviour`, waiting for feel check |

## Boot time (slice 7)

Measured in the VM (`systemd-analyze`, after the first-boot setup had finished, TPM unlock, no password):

| | Firmware | Loader | Kernel | Initrd | Userspace | Total |
|---|---|---|---|---|---|---|
| Before slice 7 | 2.0 s | 3.4 s | 0.76 s | 2.3 s | 3.87 s | 12.4 s |
| After slice 7 | 2.0 s | 3.4 s | 0.78 s | 2.3 s | 4.00 s | 12.4 s |

Userspace is already lean: the slowest path is NetworkManager → wait-online (0.15 s) → docker (0.9 s) → multi-user.
Nothing there is waste the server can do without, so nothing was cut (the 0.1 s difference is noise between runs).
On the G14, Wi-Fi can make wait-online take a few seconds, but that only delays docker, not the login screen.
Loader, kernel and initrd belong to slice 5 (silent boot).

