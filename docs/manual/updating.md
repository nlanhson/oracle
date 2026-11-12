# Updating

Type:

```sh
oracle update
```

It:

1. Saves a snapshot, so you can roll back.
2. Downloads the newest Oracle and applies its new features and fixes.
3. Updates every program on the system (`pacman -Syu`), plus Brave Origin and the other AUR programs.
4. Updates firmware (BIOS, SSD, touchpad) when the maker publishes one.
5. Tells you if a restart is needed (for example after a new Linux kernel).

## The update notice

Once a week Oracle checks quietly whether updates are waiting. It never installs anything by itself. When something new turns up, you get one small notification, like "Updates are ready: 23 packages and a newer Oracle. Run oracle update when it suits you.", and the dashboard shows the count next to `[u]pdate`. It does not ask again for the same updates. Offline, it says nothing and tries later.

To check right now without installing: `oracle update --check`.

## Roll back an update

Before every update (and every program you install), Oracle saves a snapshot of the system. If something breaks after an update, type:

```sh
oracle rollback
```

Pick the update from the list, newest first. Oracle puts back the system files that update changed, then asks you to restart. Your own files (documents, photos, settings) are never touched. Changed your mind? Run `oracle rollback` again and pick the line that starts with "rollback". The settings screen has a **rollback** button too.

**If Oracle doesn't start at all:** restart and tap `M` until the boot menu shows, then open **Snapshots**. Pick one from before the update and start it. Once logged in, type `oracle rollback` to keep that older system for good.

Oracle keeps the last 20 snapshots and deletes older ones by itself.

**Your settings are safe.** Oracle keeps its defaults in `~/.local/share/oracle/default/`. Your own files (`~/.config/hypr/hyprland.lua`, `~/.config/ghostty/mine`, `~/.config/tmux/tmux.conf`, and what you chose in Settings) are never changed by an update.

## Trying a preview

Want to see a big change on your own laptop before it becomes the real Oracle? Run:

```sh
oracle try feel/try
```

(use the branch name you were given). It tells you what will happen and asks first. Then it:

1. Takes a system snapshot, and copies your Oracle settings (`~/.config` without browser profiles and caches, the Oracle state with the update marks, the shell start files, the grey folder icons, a few appearance settings, the list of your programs) into `~/.local/state/oracle/try/<date>/`.
2. Switches Oracle to that branch and runs the normal update from it.
3. Tells you to restart. Log in again and look around. Your home server and photos keep running the whole time.

`oracle try status` says if a preview is on. While it is, `oracle update` updates that branch (not main), and `oracle doctor` shows one calm line about it.

**To go back:** `oracle try back`, then restart. It puts back, in this order: Oracle's own files (main), your settings and the update marks (so the real update later runs everything again), the appearance settings, then the programs and system files from the snapshot. It checks the list of programs is the same as before. Photos, the server and containers are not part of this and are never touched. The saved copy is never deleted by Oracle. If `oracle try back` won't run: `bash ~/.local/state/oracle/try/oracle try back`.

**What does not come back exactly:** things you changed in your Oracle settings or the system *during* the preview go back to before it too. A browser profile, caches and anything over 20 MB in `~/.config` are left as they are. If the preview later becomes the real Oracle (main holds it), the next `oracle update` closes the preview by itself and keeps the saved copy.

**Tip:** restart after big updates. A system that runs for weeks on an old kernel can break things like graphics or USB.
