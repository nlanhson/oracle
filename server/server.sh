#!/usr/bin/env bash
# Oracle home server: docker + tailscale + stacks in ~/dockge, ~/docker/<app>. Re-runnable.
# server.sh [--dry-run] [--restore <backup>]   setup → restore → start apps whose secrets exist
# server.sh start                              start apps only (oracle-firstboot unit after a USB install)
# server.sh backup <dir> [--dry-run]           fresh DB dump + photos + configs + tailscale state → <dir>, verified
set -euo pipefail

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
D=$HOME/docker I=$HOME/docker/immich L=$HOME/docker/immich/library
DONE=$HOME/.local/state/oracle/done U=$(id -un)
DRY=0 MODE=setup B='' STEPS=()

say() { printf '\e[36m::\e[0m %s\n' "$*"; }
die() { printf '\e[31m!! %s\e[0m\n' "$*" >&2; exit 1; }
run() { if ((DRY)); then printf '   would run: %s\n' "$*"; else "$@"; fi; }
todo() { STEPS+=("$*"); }
sysd() { [[ -d /run/systemd/system ]]; }
mark() { run mkdir -p "$DONE"; run touch "$DONE/$1"; }
done_() { [[ -f $DONE/$1 ]]; }
dk_init() { DK=(docker); docker info &>/dev/null || DK=(sudo docker); }
sql() { "${DK[@]}" exec immich_postgres psql -U postgres -d "$1" -Atc "$2"; }
assets_in() { gunzip -c "$1" | awk '/^COPY public\.asset \(/{f=1;next} f&&/^\\\.$/{f=0} f{n++} END{print n+0}'; }
newest_dump() { ls "$1"/immich-db-backup-*.sql.gz 2>/dev/null | sort | tail -1 || true; }

while (($#)); do
  case $1 in
    --dry-run) DRY=1 ;;
    --restore) B=${2:?--restore needs a folder}; shift ;;
    backup) MODE=backup B=${2:?backup needs a folder}; shift ;;
    start) MODE=start ;;
    *) die "unknown option $1" ;;
  esac
  shift
done

put() { # root-owned file with exact content
  [[ -f $1 && $(<"$1") == "$2" ]] && return
  say "  write $1"
  ((DRY)) && return
  sudo mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" | sudo tee "$1" >/dev/null
}

place() { # repo file → home, ${HOME} expanded, only if missing
  local new; new=$(sed "s|\${HOME}|$HOME|g" "$SRC/$1")
  if [[ -e $2 ]]; then [[ $(<"$2") == "$new" ]] || say "  kept your $2"; return; fi
  say "  $2"
  ((DRY)) && return
  mkdir -p "$(dirname "$2")"; printf '%s\n' "$new" >"$2"
}

setup() {
  say "server: docker + tailscale"
  if sysd; then run sudo systemctl enable --now docker tailscaled; else run sudo systemctl enable docker tailscaled; fi
  getent group docker | cut -d: -f4 | tr , '\n' | grep -qx "$U" || run sudo usermod -aG docker "$U"
  say "server: lid closed = keep running"
  put /etc/systemd/logind.conf.d/oracle-server.conf $'[Login]\nHandleLidSwitch=ignore\nHandleLidSwitchExternalPower=ignore\nHandleLidSwitchDocked=ignore\nIdleAction=ignore'
  say "server: stacks"
  place dockge/compose.yaml "$HOME/dockge/compose.yaml"
  place immich/docker-compose.yml "$I/docker-compose.yml"
  place vpn/compose.yaml "$D/vpn/compose.yaml"
}

restore() {
  [[ -d $B/immich ]] || B=$(ls -d "$B"/oracle-*/ 2>/dev/null | sort | tail -1 || true)
  B=${B%/}; local C=$B/configs
  [[ -d $B/immich/library/upload ]] || die "no Oracle backup in ${B:-that folder}"
  say "restore from $B"
  for f in docker/immich/.env docker/vpn/.env; do
    if [[ -f $C/$f && ! -e $HOME/$f ]]; then say "  ~/$f"; run install -Dm600 "$C/$f" "$HOME/$f"; fi
  done
  if [[ -d $C/dockge/data && ! -e $HOME/dockge/data ]]; then say "  dockge login"; run cp -r "$C/dockge/data" "$HOME/dockge/"; fi
  if [[ -f $C/tailscale-host.tar.gz ]] && ! done_ tailscale-host; then
    say "  tailscale login (this laptop, keeps its IP)"
    if sysd; then run sudo systemctl stop tailscaled; fi
    run sudo mkdir -p /var/lib/tailscale
    run sudo tar xzf "$C/tailscale-host.tar.gz" -C /var/lib/tailscale
    if sysd; then run sudo systemctl start tailscaled; fi
    mark tailscale-host
  fi
  if [[ -f $C/tailscale-vpn.tar.gz ]] && ! sudo test -e "$D/vpn/tailscale/tailscaled.state"; then
    say "  tailscale login (vpn-exit)"
    run sudo mkdir -p "$D/vpn/tailscale"
    run sudo tar xzf "$C/tailscale-vpn.tar.gz" -C "$D/vpn/tailscale"
  fi

  if ! done_ immich-photos; then
    say "  photos → $L/upload"
    run mkdir -p "$L/backups"
    run cp -r --update=none --preserve=timestamps "$B/immich/library/upload" "$L/"
    run cp --update=none "$B"/immich/library/backups/*.sql.gz "$L/backups/"
    if [[ -f $B/upload.sha256 ]]; then
      say "  check every photo (sha256)"
      ((DRY)) || (cd "$L/upload" && sha256sum -c --quiet "$B/upload.sha256") || die "photo check failed"
    fi
    for d in thumbs encoded-video profile library backups; do
      [[ -f $L/$d/.immich ]] || { run mkdir -p "$L/$d"; run cp "$L/upload/.immich" "$L/$d/.immich"; }
    done
    mark immich-photos
  fi

  done_ immich-db && return
  local dump pin; dump=$(newest_dump "$B/immich/library/backups"); [[ -n $dump ]] || ((DRY)) || die "no database dump in $B"
  [[ -f $I/.env ]] || ((DRY)) || die "no Immich .env in backup ($C/docker/immich/.env)"
  [[ -z $(sudo ls -A "$I/postgres" 2>/dev/null) ]] || die "$I/postgres already has a database. Owner must OK deleting it, then rerun."
  pin=$(grep -m1 -oP 'IMMICH_VERSION:-v\K[0-9]+' "$SRC/immich/docker-compose.yml")
  [[ ! $dump =~ -v([0-9]+)\. ]] || ((BASH_REMATCH[1] <= pin)) || die "dump is from Immich v${BASH_REMATCH[1]}, Oracle pins v$pin"
  say "  database ← ${dump##*/}"
  if ((DRY)); then echo "   would load it into immich_postgres, fix db name (lesson 1), check asset count"; return; fi
  sudo docker info &>/dev/null || { todo "Reboot, then run the installer again with --restore to load the Immich database."; return; }
  dk_init
  (cd "$I" && "${DK[@]}" compose create --quiet-pull && "${DK[@]}" start immich_postgres) >/dev/null
  for _ in {1..120}; do
    "${DK[@]}" logs immich_postgres 2>&1 | grep 'init process complete' >/dev/null && sql postgres 'select 1' &>/dev/null && break
    sleep 2
  done
  local log=$HOME/.local/state/oracle/immich-restore.log
  gunzip -c "$dump" \
    | sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
    | "${DK[@]}" exec -i immich_postgres psql -q -U postgres -d postgres >"$log" 2>&1
  if [[ -n $(sql postgres "select to_regclass('public.asset')") ]]; then
    "${DK[@]}" exec immich_postgres psql -q -U postgres -d template1 \
      -c 'DROP DATABASE IF EXISTS immich;' -c 'ALTER DATABASE postgres RENAME TO immich;' -c 'CREATE DATABASE postgres;'
  fi
  local want got; want=$(assets_in "$dump"); got=$(sql immich 'select count(*) from asset' 2>/dev/null || echo none)
  [[ $got == "$want" ]] || die "Immich database check failed: $got assets, dump has $want. Log: $log"
  say "  database ok: $got photos/videos"
  mark immich-db
  todo "Immich: open http://localhost:2283 → Administration → Job Queues → run 'Generate Thumbnails: Missing' and 'Transcode Videos: Missing'."
}

up() { say "  start ${1##*/}"; if ((DRY)); then echo "   would run: docker compose up -d in $1"; else (cd "$1" && "${DK[@]}" compose up -d --quiet-pull); fi; }

start() {
  say "server: start apps"
  dk_init
  if ! "${DK[@]}" info &>/dev/null; then
    [[ -n ${ORACLE_CHROOT:-} ]] || { todo "Reboot, then run the installer again to start the server apps."; return; }
    say "  on first boot (oracle-firstboot, retries until online, then disables itself)"
    put /etc/systemd/system/oracle-firstboot.service "[Unit]
Description=Oracle first boot: start server apps
Wants=network-online.target docker.service
After=network-online.target docker.service
[Service]
Type=oneshot
User=$U
ExecStart=/usr/bin/bash $SRC/server.sh start
ExecStartPost=+/usr/bin/systemctl disable oracle-firstboot.service
Restart=on-failure
RestartSec=30
[Install]
WantedBy=multi-user.target"
    run sudo systemctl enable oracle-firstboot.service
    return
  fi
  [[ -d $HOME/dockge/data ]] || todo "Dockge: open http://localhost:5001 and create a login."
  up "$HOME/dockge"
  if [[ -f $I/.env ]]; then up "$I" || todo "Immich didn't start: check 'docker logs immich_server'."; else todo "Immich: no backup given. Rerun with --restore <backup folder>, or start empty (homeserver README step 4)."; fi
  if grep -q '^WIREGUARD_PRIVATE_KEY=..' "$D/vpn/.env" 2>/dev/null && ! grep -q CHANGE_ME "$D/vpn/.env" \
    && { [[ -f $D/vpn/ts.env ]] || sudo test -e "$D/vpn/tailscale/tailscaled.state"; }; then
    up "$D/vpn" || todo "VPN didn't start: check 'docker logs gluetun' (ProtonVPN key ok?)."
  else
    todo "VPN exit node: put the ProtonVPN key in ~/docker/vpn/.env and a Tailscale auth key in ~/docker/vpn/ts.env (homeserver README step 5), then rerun."
  fi
  if ! done_ tailscale-host && ! tailscale status &>/dev/null; then
    todo "Tailscale: run 'sudo tailscale up --operator=$U', open the link, log in. Then point the phone's Immich app at the new IP (sign out + in)."
  fi
}

backup() {
  [[ -d $L/upload ]] || die "no Immich library at $L"
  dk_init
  local T=$B/immich/library C=$B/configs
  run mkdir -p "$T/backups" "$C/docker/immich" "$C/docker/vpn" "$C/dockge"
  local need free
  need=$(comm -23 <(cd "$L/upload" && find . -type f | sort) <(cd "$T/upload" 2>/dev/null && find . -type f | sort) \
    | (cd "$L/upload" && xargs -d '\n' -r stat -c %s) | awk '{s+=$1} END{print s+0}')
  free=$(df -B1 --output=avail "$( [[ -d $B ]] && echo "$B" || dirname "$B")" | tail -1)
  ((need + 200000000 < free)) || die "not enough space in $B: need $((need / 1000000)) MB + 200 MB, free $((free / 1000000)) MB"
  say "backup → $B ($((need / 1000000)) MB new photos)"

  say "  fresh database dump"
  local ver pg out live
  ver=$("${DK[@]}" exec immich_server sh -c 'grep -m1 "\"version\"" /usr/src/app/server/package.json' | cut -d'"' -f4)
  pg=$(sql immich 'show server_version' | cut -d' ' -f1)
  out=$T/backups/immich-db-backup-$(date +%Y%m%dT%H%M%S)-v${ver:-unknown}-pg$pg-manual.sql.gz
  live=$(sql immich 'select count(*) from asset')
  if ((DRY)); then echo "   would dump to $out"; else
    "${DK[@]}" exec immich_postgres pg_dump --clean --if-exists -U postgres immich | gzip >"$out.part"
    gzip -t "$out.part" && mv "$out.part" "$out"
    [[ $(assets_in "$out") == "$live" ]] || die "dump check failed: $(assets_in "$out") assets in dump, $live live"
  fi
  local nd; nd=$(newest_dump "$L/backups")
  run cp --update=none ${nd:+"$nd"} "$L/backups/.immich" "$T/backups/"

  say "  photos"
  ((DRY)) || (cd "$L/upload" && find . -type f ! -name .immich -print0 | sort -z | xargs -0 sha256sum) >"$B/upload.sha256"
  run cp -r --update=none --preserve=timestamps "$L/upload" "$T/"

  say "  configs + tailscale state"
  for f in docker/immich/docker-compose.yml docker/immich/.env docker/vpn/compose.yaml docker/vpn/.env dockge/compose.yaml; do
    [[ ! -f $HOME/$f ]] || run cp "$HOME/$f" "$C/$f"
  done
  [[ ! -d $HOME/dockge/data ]] || run cp -r "$HOME/dockge/data" "$C/dockge/"
  run sudo tar czf "$C/tailscale-host.tar.gz" -C /var/lib/tailscale .
  ! sudo test -d "$D/vpn/tailscale" || run sudo tar czf "$C/tailscale-vpn.tar.gz" -C "$D/vpn/tailscale" .
  run sudo chmod 600 "$C"/tailscale-*.tar.gz
  ((DRY)) && return

  say "  verify: read every photo back from $B"
  sync; echo 1 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
  (cd "$T/upload" && sha256sum -c --quiet "$B/upload.sha256") || die "copy check FAILED"
  for t in "$C"/tailscale-*.tar.gz; do sudo tar tzf "$t" >/dev/null || die "bad $t"; done
  say "backup ok: $(wc -l <"$B/upload.sha256") photo files, $live assets in database, $(du -sh "$B" | cut -f1) in $B"
}

case $MODE in
  backup) backup ;;
  setup | start)
    [[ $MODE == start ]] || setup
    [[ -z $B ]] || restore
    start
    if ((${#STEPS[@]})); then
      say "server: steps for you"
      i=0; for s in "${STEPS[@]}"; do printf '   %d. %s\n' $((++i)) "$s"; done
    fi
    ;;
esac
