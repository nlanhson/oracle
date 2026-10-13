# Hardware: cpu/gpu/ram/temperature sparklines (one sample per refresh), disk + battery meters.
HIST=() GHIST=() MHIST=() THIST=() P_IDLE=0 P_TOT=0
cpu() {
  local _ u n s i w x y z idle tot
  read -r _ u n s i w x y z _ </proc/stat
  idle=$((i + w)) tot=$((u + n + s + i + w + x + y + z))
  local d=$((tot - P_TOT)) di=$((idle - P_IDLE)); P_TOT=$tot P_IDLE=$idle
  CPU=0; ((d > 0)) && CPU=$((100 * (d - di) / d))
}
gpu() { local f; for f in /sys/class/drm/card*/device/gpu_busy_percent; do [[ -r $f ]] && { cat "$f"; return; }; done; }
temp() { # the laptop's own sensor (acpitz, what the fans follow), else the CPU's
  local f n=''; for f in /sys/class/hwmon/hwmon*/name; do [[ -f $f ]] || continue
    case $(<"$f") in acpitz) n=${f%name}temp1_input; break ;; k10temp | coretemp) n=${f%name}temp1_input ;; esac; done
  [[ -r $n ]] && echo $(($(<"$n") / 1000))
}
push() { local -n a=$1; a+=("$2"); ((${#a[@]} > SW)) && a=("${a[@]: -SW}"); }
cpu
w_system() {
  local g m t b L s p u tot
  title system
  cpu; push HIST "$CPU"; t=$(temp)
  spark cpu "$CPU%" "" "${HIST[@]}"
  g=$(gpu); if num "$g"; then push GHIST "$g"; spark gpu "$g%" "" "${GHIST[@]}"; fi
  m=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%d %.1f %.1f",100*(t-a)/t,(t-a)/1048576,t/1048576}' /proc/meminfo)
  read -r p u tot <<<"$m"; push MHIST "$p"
  spark ram "$u gb" "of $tot" "${MHIST[@]}"
  if num "$t"; then push THIST $((t > 100 ? 100 : t)); spark temperature "${t}°c" "" "${THIST[@]}"; fi
  printf "${D}%12s%-$((SW - 2))s%s${N}\n\n" '' "$((SW * 2))s ago" now
  b=$(df --output=pcent,used,size -BG / | awk 'NR==2{print $1+0, $2" of "$3}')
  meter "${b%% *}" disk "${b#* }"
  [[ -r /etc/oracle/battery-limit ]] && L=$(</etc/oracle/battery-limit)
  s=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1); s=${s,,}
  meter "$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)" battery "${s}${L:+ · limit $L%}"
  echo
}
