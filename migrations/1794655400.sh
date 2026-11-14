# Notification Center: "No Notifications" sits at the top (where the first card would be) instead of mid-screen, and a long list uses the whole screen height. An untouched copy of the previous Feel config gets the new one; a file you changed keeps your version (nothing saved over, nothing deleted).
D=$HOME/.local/share/oracle f=$HOME/.config/swaync/config.json
[[ -f $f ]] || exit 0
h=$(sha256sum "$f" | cut -d' ' -f1)
if [[ $h == 73f1946c4664f0bad1a3bff0466b6af3f2f52bae4c6e81a46d7cfe6266b63198 ]]; then
  cp "$D/config/swaync/config.json" "$f"; swaync-client -R -sw &>/dev/null || true
elif grep -q '"control-center-height": 640' "$f"; then
  echo "~/.config/swaync/config.json keeps your own version (you edited it): the empty Notification Center line stays mid-screen. To get the new one: rename it (mv ~/.config/swaync/config.json ~/.config/swaync/config.json.old), then run: oracle update"
fi
