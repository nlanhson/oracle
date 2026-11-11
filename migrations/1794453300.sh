# Control panel: untouched old copies of the notification config and the bar config get the new Oracle ones (panel tiles, sliders,
# click the status icons to open it, unread dot). A file you changed keeps your version: nothing saved over, nothing deleted.
D=$HOME/.local/share/oracle C=$HOME/.config
swap() { # swap <path under ~/.config> <sha256 of an old Oracle version>…
  local f=$C/$1 h x; shift; [[ -f $f ]] || return 0
  h=$(sha256sum "$f" | cut -d' ' -f1)
  for x in "$@"; do
    [[ $h == "$x" ]] || continue
    sed "s|@HOME@|$HOME|g" "$D/config/${f#"$C/"}" >"$f"; return 0
  done
  grep -q 'swaync-client' "$f" || echo "~/.config/${f#"$C/"} keeps your own version (you edited it). To get the control panel: rename it (mv ~/.config/${f#"$C/"} ~/.config/${f#"$C/"}.old), then run: oracle update"
}
swap swaync/config.json 83fb244df0f716ac3df602bb0cd9c6a43b77a767de5c91fb75191a63d57d50f5 dd46e08f6a5ee509a14645c364c106d2f9c2a2862c3784c1d196c75a232cbc67
swap waybar/config.jsonc 48f4dcc1c1b0dbf31d3ccf2e9cdb0591bd174c830cb876f801779d07e781620b 0d12aa5f9516e1bc6c351c8d302156c94fe3cb7c2df5cf0451fb439a74b58e42 1882e1cbb9f2cdeb43f5a54c9180de42379cdfe9071c79fcc0d16c54c2b69613 ac43d81577364410d95bc88dd6c3caad4ae6d517cbe059bc062f05237701e4aa
pkill -USR2 -x waybar || true
swaync-client -R -sw &>/dev/null || true
