# cpu + gpu sparklines, ram/disk/battery/volume/brightness bars.
HIST=() GHIST=() P_IDLE=0 P_TOT=0
cpu() {
  local _ u n s i w x y z idle tot
  read -r _ u n s i w x y z _ </proc/stat
  idle=$((i + w)) tot=$((u + n + s + i + w + x + y + z))
  local d=$((tot - P_TOT)) di=$((idle - P_IDLE)); P_TOT=$tot P_IDLE=$idle
  CPU=0; ((d > 0)) && CPU=$((100 * (d - di) / d))
}
gpu() { local f; for f in /sys/class/drm/card*/device/gpu_busy_percent; do [[ -r $f ]] && { cat "$f"; return; }; done; }
temp() { local f; for f in /sys/class/hwmon/hwmon*/name; do [[ -f $f ]] || continue; [[ $(<"$f") == k10temp || $(<"$f") == coretemp ]] && { echo $(($(<"${f%name}temp1_input") / 1000)); return; }; done; }
cpu
w_system() {
  local g m t b
  cpu; HIST+=("$CPU"); ((${#HIST[@]} > 30)) && HIST=("${HIST[@]:1}")
  g=$(gpu); [[ $g =~ ^[0-9]+$ ]] && { GHIST+=("$g"); ((${#GHIST[@]} > 30)) && GHIST=("${GHIST[@]:1}"); }
  t=$(temp)
  printf "  ${W}%-9s${C}%-30s${W} %3d%%${D} %s${N}\n" cpu "$(spark "${HIST[@]}")" "$CPU" "${t:+${t}°C}"
  [[ -n $g ]] && printf "  ${W}%-9s${C}%-30s${W} %3d%%${N}\n" gpu "$(spark "${GHIST[@]}")" "$g"
  m=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%d %.1f/%.1fG",100*(t-a)/t,(t-a)/1048576,t/1048576}' /proc/meminfo)
  bar "${m%% *}" ram "${m#* }"
  b=$(df --output=pcent,used,size -BG / | awk 'NR==2{print $1+0, $2"/"$3}')
  bar "${b%% *}" disk "${b#* }"
  bar "$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)" battery "$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1 | tr A-Z a-z)"
  bar "$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100)}')" volume ""
  bar "$(brightnessctl -m 2>/dev/null | awk -F, '{print $4+0}')" bright ""
  echo
}
