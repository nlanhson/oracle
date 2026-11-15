# Notification Center: an untouched old copy of the notification config gets the new Oracle one (cards only; the Control Center is Quickshell). A file you changed keeps your version: nothing saved over, nothing deleted.
D=$HOME/.local/share/oracle C=$HOME/.config
swap() { # swap <path under ~/.config> <sha256 of an old Oracle version>…
  local f=$C/$1 h x; shift; [[ -f $f ]] || return 0
  h=$(sha256sum "$f" | cut -d' ' -f1)
  for x in "$@"; do
    [[ $h == "$x" ]] || continue
    sed "s|@HOME@|$HOME|g" "$D/config/${f#"$C/"}" >"$f"; return 0
  done
  grep -q 'swaync-client' "$f" || echo "~/.config/${f#"$C/"} keeps your own version (you edited it). To get the new Notification Center: rename it (mv ~/.config/${f#"$C/"} ~/.config/${f#"$C/"}.old), then run: oracle update"
}
swap swaync/config.json 83fb244df0f716ac3df602bb0cd9c6a43b77a767de5c91fb75191a63d57d50f5 dd46e08f6a5ee509a14645c364c106d2f9c2a2862c3784c1d196c75a232cbc67
swaync-client -R -sw &>/dev/null || true
