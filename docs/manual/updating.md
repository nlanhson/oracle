# Updating

Type:

```sh
oracle update
```

It:

1. Downloads the newest Oracle.
2. Applies any new Oracle features and fixes.
3. Updates every program on the system, including Brave Origin.
4. Tells you if a restart is needed (for example after a new Linux kernel).

## Undo an update

Before every update (and every program you install), Oracle saves a snapshot of the system. If something breaks after an update, type:

```sh
oracle undo
```

Pick the update from the list, newest first. Oracle puts back the system files that update changed, then asks you to restart. Your own files (documents, photos, settings) are never touched. Changed your mind? Run `oracle undo` again and pick the line that starts with "undo".

Oracle keeps the last 20 snapshots and deletes older ones by itself.

**Your settings are safe.** Oracle keeps its defaults in `~/.local/share/oracle/default/`. Your own files (`~/.config/hypr/hyprland.lua`, `~/.config/ghostty/mine`, `~/.config/tmux/tmux.conf`, and what you chose in Settings) are never changed by an update.

**Tip:** restart after big updates. A system that runs for weeks on an old kernel can break things like graphics or USB.
