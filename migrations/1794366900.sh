# One look: untouched old copies of the bar, launcher, notification and lock styles become small stubs that import the shared look
# (default/look/tokens). A file you changed keeps its own look: nothing saved over, nothing deleted. Also: bar clock in 12 hours.
D=$HOME/.local/share/oracle C=$HOME/.config
swap() { # swap <path under ~/.config> <sha256 of an old Oracle version>…
  local f=$C/$1 h x; shift; [[ -f $f ]] || return 0
  h=$(sha256sum "$f" | cut -d' ' -f1)
  for x in "$@"; do
    [[ $h == "$x" ]] || continue
    sed "s|@HOME@|$HOME|g" "$D/config/${f#"$C/"}" >"$f"; return 0
  done
  grep -q 'oracle/look/' "$f" || echo "~/.config/${f#"$C/"} keeps your own look (you edited it). To use Oracle's shared look: rename it (mv ~/.config/${f#"$C/"} ~/.config/${f#"$C/"}.old), then run: oracle update"
}
swap waybar/style.css 192cb9dfd7b1d3a2f8970543a4d5cdaaf06bf3f3c25c27a5de86dbff415aa6d5
swap fuzzel/fuzzel.ini 1a592881ff00ca3d3a191c288b1913de89611a1473eafed2c77c595c58d07d8f 809f97bfcbbbd41449fc3c2714582031243000eceb9906330d562002238b794c
swap swaync/style.css df4509b4d51c40b63e64847ca9c935acc32806e66716cd05209a5e4fcabad9f6
swap hypr/hyprlock.conf 60c305fb7c331e64a100339ddcaf1c8067181d251811d81bb67b19725c4b0a1c 52400ad30c16ae7714a2936f010c84ee42449e0fcdf62c4181077eeda9d950f0
W=$C/waybar/config.jsonc # clock: 5:15 PM, not 05:15 (only if the line is still Oracle's)
[[ ! -f $W ]] || sed -i "s|\"date +'%I:%M %a,%d/%m'\",/\*Only Time: date '+%I:%M %p'\*/|\"date +'%-I:%M %p %a, %d/%m'\",|" "$W"
[[ ! -f $W ]] || sed -i 's|"format": "󰍛 {used}"|"format": "󰍛 {used:0.1f}G"|' "$W" # memory: 1.3G, not 1.3399999
bash "$D/bin/oracle" look || true # the stubs need ~/.config/oracle/look/colors.css
pkill -USR2 -x waybar || true
