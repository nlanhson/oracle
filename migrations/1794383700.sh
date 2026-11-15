# System logic: an untouched copy of the idle timers becomes the new one (shorter on battery, keyboard light off).
# A file you changed is left alone, with one line saying where the new one is.
D=$HOME/.local/share/oracle C=$HOME/.config
swap() { # swap <path under ~/.config> <sha256 of an old Oracle version>…
  local f=$C/$1 h x; shift; [[ -f $f ]] || return 0
  h=$(sha256sum "$f" | cut -d' ' -f1)
  for x in "$@"; do [[ $h == "$x" ]] && { install -m"$(stat -c %a "$f")" "$D/config/${f#"$C/"}" "$f"; return 0; }; done
  cmp -s "$f" "$D/config/${f#"$C/"}" || echo "~/.config/${f#"$C/"} is your own version, kept. The new one is in $D/config/${f#"$C/"}"
  return 1
}
if swap hypr/hypridle.conf f9399062493daa4fcc9fd5cc8fdbd1e913c46bfd66f224631e8cb3658124cc08 && pgrep -x hypridle >/dev/null; then # new timers now
  l=$(hyprctl instances 2>/dev/null | awk '/^instance /{i=substr($2, 1, length($2) - 1)} /wl socket:/{print i, $3; exit}')
  [[ -z $l ]] || { pkill -x hypridle; HYPRLAND_INSTANCE_SIGNATURE=${l% *} WAYLAND_DISPLAY=${l#* } setsid -f hypridle &>/dev/null; }
fi
exit 0
