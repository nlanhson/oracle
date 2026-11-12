# Home server: the details

Oracle sets the server up for you (see [Backup and home server](manual/backup.md)). This page is for the rest: how it fits together, updating the apps, what to back up, fixing it by hand, and the problems that already happened once. It replaces the old `homeserver` repo; Oracle's `server/` folder is now the only copy of the setup files.

## How it fits together

| App | Folder | On the laptop | From the phone (Tailscale on) |
|---|---|---|---|
| Immich (photos) | `~/docker/immich/` | http://localhost:2283 | `https://<laptop>.<tailnet>.ts.net` |
| Dockge (dashboard) | `~/dockge/` | http://localhost:5001 | `https://<laptop>.<tailnet>.ts.net:8443` |
| ProtonVPN exit node | `~/docker/vpn/` | — | Tailscale device `vpn-exit` |

```
phone ──Tailscale──► laptop (tailscale serve :443)  ──► Immich
phone ──Tailscale──► laptop (tailscale serve :8443) ──► Dockge
phone ──Tailscale──► vpn-exit (inside Gluetun) ──ProtonVPN Singapore──► internet
```

- **Apps only listen on the laptop itself** (`127.0.0.1`). Docker skips the firewall, so a plain `"5001:5001"` would open the app to everyone on the Wi-Fi. The phone gets in through `tailscale serve`, which only devices logged in to your Tailscale can reach.
- **Firewall (ufw):** nothing comes in except Tailscale. `oracle doctor` checks it.
- `server.sh` sets up `tailscale serve` by itself. It needs **MagicDNS** and **HTTPS Certificates** turned on once at https://login.tailscale.com/admin/dns. Check with `tailscale serve status`.
- Never use `tailscale funnel` for Dockge: that puts it on the public internet, and Dockge controls everything on the laptop.
- Every app has its own folder under `~/docker/`, and Dockge shows them all. Dockge itself lives in `~/dockge/` so it can't stop itself by accident.
- **It never goes off by accident.** The machine never sleeps by itself, a press of the power button does nothing to the server (the desktop shows the power menu instead), and on a dying battery it shuts down cleanly at 4%: docker stops the apps first, so Postgres closes its files properly. It comes back by itself after a power cut. To make a press shut down again, put `[Login]` and `HandlePowerKey=poweroff` on two lines in `/etc/systemd/logind.conf.d/zz-mine.conf` (it loads after Oracle's), then restart. To stop the battery rules: `sudo systemctl mask --now oracle-power.service` (`unmask` brings them back).
- **If a server app stops**, you get one notification ("Immich is not working ... Check it with: oracle doctor"), at most once a day.
- The laptop sits on an apartment Wi-Fi with no router access, so no port forwarding: everything goes through Tailscale.

## Updating the apps

Every image is pinned to an exact version (for example `louislam/dockge:1.5.0`), so nothing changes behind your back.

1. Read the release notes first, especially for Immich and especially for a big jump (v3 → v4).
2. Change the version: Immich = `IMMICH_VERSION` in `~/docker/immich/.env`, the others = the `image:` line in their `compose.yaml`.
3. In that app's folder: `docker compose pull && docker compose up -d`.

For the VPN, always update the **whole** `vpn` app, never just `gluetun` (see lesson 6).

## What to back up

The original photos also live in iCloud Photos and cloud storage, so losing the laptop doesn't lose them. What only lives on the laptop:

| What | Where | Why |
|---|---|---|
| Immich database dumps | `~/docker/immich/library/backups/` | Albums, favourites, people, descriptions. The photos alone don't have these. |
| Setup secrets | `.env` files in `~/docker/*/` | Can be made again (new DB password, new ProtonVPN key), just annoying. |
| Tailscale logins | `/var/lib/tailscale`, `~/docker/vpn/tailscale/` | Keeps the same address, so the phone keeps working. |

`oracle backup <folder>` copies all of it and checks every photo. Previews (`thumbs/`, `encoded-video/`) never need a backup: Immich rebuilds them.

## Starting without a backup

- **Immich:** in `~/docker/immich/`, copy `~/.local/share/oracle/server/immich/.env.example` to `.env`, set a random `DB_PASSWORD` (letters and numbers only), `chmod 600 .env`, then `docker compose up -d` and open http://localhost:2283 to create the admin account.
- **Tailscale:** `sudo tailscale up --operator=$USER`, open the link, log in. Then `oracle update` shares Immich and Dockge with the phone.
- **Phone:** install Immich, set the server to the `https://…ts.net` address, log in, Backup → **Recents** → on. In iOS Settings, turn on **Background App Refresh** for Immich.
- **VPN exit node:**
  1. ProtonVPN key: account.protonvpn.com → Downloads → WireGuard configuration. Platform **GNU/Linux**, NetShield off, Moderate NAT off, NAT-PMP off, VPN Accelerator on, any **free** server.
  2. Copy only the `PrivateKey` into `~/docker/vpn/.env` (template: `server/vpn/.env.example`), `chmod 600`. Don't paste the key into a chat. Delete the downloaded file.
  3. Tailscale admin → Settings → Keys → Generate auth key (reusable off, ephemeral off). Put `TS_AUTHKEY=tskey-auth-…` in `~/docker/vpn/ts.env`, `chmod 600`.
  4. `oracle update` (or `cd ~/docker/vpn && docker compose up -d`). Check: `docker exec gluetun wget -qO- https://ipinfo.io/json` says Singapore.
  5. Once `vpn-exit` shows up in Tailscale, delete `ts.env`. In the admin console: `vpn-exit` → Edit route settings → **Use as exit node**, then **Disable key expiry**.
  6. Phone: Tailscale → Exit Node → **vpn-exit**. Test: ipinfo.io says Singapore, dnsleaktest.com shows only Cloudflare.

**Choosing the VPN country:** Gluetun picks at random, not by speed. List the free servers with `docker run --rm --entrypoint /gluetun-entrypoint qmcgaw/gluetun:v3.41.3 format-servers -protonvpn -format json`, ping one per country, set `SERVER_COUNTRIES` to the fastest. From Vietnam (Sep 2026): Singapore 50 ms (chosen), Japan 85 ms, Switzerland 195 ms, the rest 230 ms or more.

## Restoring Immich by hand

`oracle restore` does all of this. By hand, in `~/docker/immich/`:

1. Photos into `library/upload/`, dumps into `library/backups/`. The Immich version must be the same or newer than the one in the dump's name.
2. `docker compose create && docker start immich_postgres`
3. Load the newest dump:
   ```sh
   gunzip --stdout library/backups/<newest>.sql.gz \
   | sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
   | docker exec -i immich_postgres psql --dbname=postgres --username=postgres
   ```
4. If the tables landed in `postgres` (lesson 1):
   `docker exec immich_postgres psql -U postgres -d template1 -c 'DROP DATABASE immich;' -c 'ALTER DATABASE postgres RENAME TO immich;' -c 'CREATE DATABASE postgres;'`
5. Add the missing `.immich` markers (lesson 2), then `docker compose up -d`.
6. Web UI → Administration → Job Queues → **Generate Thumbnails: Missing** and **Transcode Videos: Missing**.
7. Phone: sign out of Immich and log in again with the server address (lesson 3).

## Lessons learned

All of these happened once already:

1. **The Immich dump is a single-database dump.** Restoring it into `postgres` leaves Immich with an empty `immich` database. Fix: rename the databases. Check: `docker exec immich_postgres psql -U postgres -d immich -c 'select count(*) from asset'`.
2. **Immich won't start after a restore** (`Failed to read .../encoded-video/.immich`). Every storage folder needs a `.immich` marker: copy `library/upload/.immich` into `thumbs/`, `encoded-video/`, `profile/`, `library/`, `backups/`.
3. **The phone app "worked" but every backup failed.** It still pointed at the old address and showed cached photos. Clue: the server logs show nothing from the phone. Fix: sign out and back in with the new address.
4. **Files on disk that aren't in the database** (uploaded after the last nightly dump) don't show in Immich. Upload them again through the web page, then delete the leftovers from `library/upload/`.
5. **The Tailscale container's login link expires after about a minute.** Use a one-time auth key instead.
6. **After recreating Gluetun, the exit node loses its network** (it lives inside Gluetun's network). Restart or update the whole `vpn` app, never just `gluetun`.
7. **The exit node needs approval** in the Tailscale admin console. Also disable key expiry, or it logs out after about 180 days.
8. **Stop/Restart/Update in Dockge interrupts uploads.** Avoid it during a big phone backup.
9. **Restart after system updates.** Skipping it once broke the graphics, another time USB.
10. **Docker ignores the firewall.** Always `"127.0.0.1:port:port"`, and `tailscale serve` for the phone. (Nov 2026: Immich and Dockge changed to this. The phone address moved from `http://<tailscale-ip>:2283` to the `https://…ts.net` one: sign out of the app and back in.)
11. **Portainer was dropped:** paid plans, heavy. Dockge is free, small, and uses plain files in `~/docker/`.
