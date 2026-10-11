# Things you set: volume, brightness.
w_controls() {
  title controls
  bar "$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100)}')" volume
  bar "$(brightnessctl -m 2>/dev/null | awk -F, '{print $4+0}')" brightness
  echo
}
