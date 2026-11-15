# Bar: the laptop-screen button is gone (closing the lid does that), and the now-playing item opens the Now Playing card. An untouched copy of the previous Feel bar config gets the new one; a file you changed keeps your version (nothing saved over, nothing deleted).
D=$HOME/.local/share/oracle f=$HOME/.config/waybar/config.jsonc
[[ -f $f ]] || exit 0
h=$(sha256sum "$f" | cut -d' ' -f1)
if [[ $h == 1d830754868228d582e310581cf220cfb940733f2f00d60b2a3a607d762e7db6 ]]; then
  cp "$D/config/waybar/config.jsonc" "$f"; pkill -USR2 -x waybar 2>/dev/null || true
elif grep -q 'custom/display' "$f"; then
  echo "~/.config/waybar/config.jsonc keeps your own version (you edited it): it still has the laptop-screen button. To get the new bar: rename it (mv ~/.config/waybar/config.jsonc ~/.config/waybar/config.jsonc.old), then run: oracle update"
fi
