# Backup and home server

Oracle can run a small home server:

| App | What it does | Address |
|---|---|---|
| Immich | Your photo library; phones back up to it | http://localhost:2283 |
| Dockge | Dashboard for the server apps | http://localhost:5001 |
| Tailscale | Reach your server from anywhere, no router setup | — |
| VPN exit node | Route your phone's traffic through ProtonVPN | — |

The dashboard shows whether each app is up.

**Closing the lid** turns the screen off and keeps everything running, so the laptop can sit closed on a shelf. Opening it brings the screen back.

**Battery:** a laptop that's always plugged in lasts longer if it doesn't sit at 100%. Oracle stops charging at 50%. Change it with `oracle battery 30` (any number from 20 to 100).

## Back up

Plug in a USB stick or drive and type:

```sh
oracle backup /run/media/$USER/<drive>/oracle-backup
```

It copies your photos, a fresh copy of the photo database, the server settings and the Tailscale login, then checks every photo against the original. Run it again any time: it only copies what's new.

**Keep the drive safe.** It contains your server passwords.

## Restore after a reinstall

Install Oracle, plug in the backup drive and type:

```sh
oracle restore /run/media/$USER/<drive>/oracle-backup
```

Everything comes back: photos, albums, accounts, the server apps and the same Tailscale address, so your phone keeps working without changes.

If it asks you to restart, restart and run the same command again.

## After a restore

In Immich, open **Administration → Job Queues** and run **Generate Thumbnails: Missing** and **Transcode Videos: Missing**. This rebuilds the previews.

## Starting without a backup

- **Immich:** open http://localhost:2283 and create an admin account.
- **Tailscale:** run `sudo tailscale up` and log in.
- **VPN exit node:** add your ProtonVPN WireGuard key to `~/docker/vpn/.env` and a Tailscale auth key to `~/docker/vpn/ts.env`, then run `oracle update`.
