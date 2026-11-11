#!/usr/bin/env bash
# System logic, no VM, nothing outside a temp HOME: battery rules (fake power supply, fake poweroff), the update check (fake
# package list, local repo one change behind), plain-word alerts (fake disk/units/crash/portal), idle steps, the config migration.
# Notifications are caught by a fake notify-send. bash test/system.sh
R=$(cd "$(dirname "$0")/.." && pwd); T=$(mktemp -d); trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$T"' EXIT
export HOME=$T/home XDG_RUNTIME_DIR=$T/xdg; mkdir -p "$HOME/.local/share" "$T/bin" "$XDG_RUNTIME_DIR"
N=$T/notes; : >"$N"; fail=0
fake() { printf '#!/bin/bash\n%s\n' "$2" >"$T/bin/$1"; chmod +x "$T/bin/$1"; }
fake notify-send 'printf "%s|" "$@" >>'"$N"'; echo >>'"$N"
fake busctl 'echo "b true"'
fake brightnessctl 'echo "$*" >>'"$T"'/bright; [[ $* != *kbd_backlight*info* ]] || [[ -n $KBD ]]'
fake hyprctl 'echo "$*" >>'"$T"'/hypr'
fake pgrep 'exit 1'; fake pkill 'exit 0' # never touch this machine's own hypridle
export PATH=$T/bin:$PATH
ck() { if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fail=1; fi; }
seen() { grep -c -- "$1" "$N"; }

# battery: 21 → 20 → 15 → 10 → 4 (AC back in time: cancelled) → 3 (no AC: poweroff)
PS=$T/ps; mkdir -p "$PS/BAT0" "$PS/AC0"; echo Battery >"$PS/BAT0/type"; echo Mains >"$PS/AC0/type"
set_b() { echo "$1" >"$PS/BAT0/capacity"; echo "$2" >"$PS/BAT0/status"; echo "$3" >"$PS/AC0/online"; }
set_b 21 Discharging 0
ORACLE_POWER_SUPPLY=$PS ORACLE_POWER_RUN=$T/run ORACLE_POWER_TICK=1 ORACLE_POWER_GRACE=4 ORACLE_POWEROFF="touch $T/poweroff" \
  bash "$R/system/oracle-power" >"$T/power.log" 2>&1 & PW=$!
sleep 2; ck "battery 21%: nothing said" '[[ ! -s $N ]]'
set_b 20 Discharging 0; sleep 2; set_b 15 Discharging 0; sleep 2
ck "battery 20%: one notice, said once" '[[ $(seen "Battery at 20%|Plug in soon.") == 1 && $(grep -c . "$N") == 1 ]]'
set_b 10 Discharging 0; sleep 2; set_b 9 Discharging 0; sleep 2
ck "battery 10%: one critical notice that stays" '[[ $(seen "critical|.*Battery at 10%|Plug in now.") == 1 && $(grep -c . "$N") == 2 ]]'
ck "dashboard line while low" 'grep -q "Plug in now" "$T/run/battery"'
set_b 4 Discharging 0; sleep 2
ck "battery 4%: shutdown announced" '[[ $(seen "Shutting down in 4 seconds to keep your data safe. Plug in to cancel.") == 1 ]]'
set_b 4 Charging 1; sleep 3
ck "AC back in time: shutdown cancelled, no poweroff" '[[ $(seen "Power is back|Shutdown cancelled.") == 1 && ! -e $T/poweroff ]]'
sleep 2; ck "on power: dashboard line cleared" '[[ ! -s $T/run/battery ]]'
set_b 3 Discharging 0; sleep 8
ck "battery 3%, no AC: clean poweroff after the wait, watcher stops" '[[ -e $T/poweroff ]] && wait $PW && grep -q "shutting down now" "$T/power.log"'
mkdir -p "$T/none"; out=$(ORACLE_POWER_SUPPLY=$T/none bash "$R/system/oracle-power"; echo "rc=$?")
ck "no battery: exits quietly" '[[ $out == *"rc=0" ]]'
cat "$T/power.log"

# update check: 2 packages waiting + Oracle one change behind → one notice; same again → none; a new package → one more
git init -qb main "$T/up"; git -C "$T/up" -c user.name=t -c user.email=t@t commit -q --allow-empty -m one
git clone -q "$T/up" "$HOME/.local/share/oracle"; git -C "$T/up" -c user.name=t -c user.email=t@t commit -q --allow-empty -m two
fake checkupdates 'cat '"$T"'/pending; [[ -s '"$T"'/pending ]] || exit 2'; fake yay 'exit 0'
printf 'linux 6.1 -> 6.2\nmesa 1 -> 2\n' >"$T/pending"; : >"$N"
W=$R/bin/oracle-watch; S=$HOME/.local/state/oracle
bash "$W" --updates
ck "update check: state file (2 packages, 1 Oracle change)" 'grep -qx packages=2 "$S/updates" && grep -qx oracle=1 "$S/updates"'
ck "update check: one quiet notice in plain words" '[[ $(seen "low|Updates are ready|2 packages and a newer Oracle. Run oracle update when it suits you.") == 1 ]]'
bash "$W" --updates; ck "update check again: nothing new, no notice" '[[ $(grep -c . "$N") == 1 ]]'
echo 'zstd 1 -> 2' >>"$T/pending"; bash "$W" --updates
ck "a new package since the notice: one more" '[[ $(grep -c . "$N") == 2 && $(seen "3 packages") == 1 ]]'
ck "nothing was installed (local repo not moved)" '[[ $(git -C "$HOME/.local/share/oracle" rev-list --count HEAD) == 1 ]]'
fake checkupdates 'exit 1'; rm "$S/updates"; bash "$W" --updates
ck "offline: silent, no state written" '[[ ! -e $S/updates && $(grep -c . "$N") == 2 ]]'
H=$HOME/.local/state/oracle/updates; printf 'packages=23\noracle=1\nchecked=1\n' >"$H"
out=$(H=$R/default/home; source "$H/theme.sh"; source "$H/footer.sh"; w_footer; echo "${FOOT[3]}")
ck "dashboard footer shows the count" '[[ $out == *"[u]pdate 24" ]]'

# alerts: full disk (threshold 0), a failed service, a crash, a sign-in Wi-Fi → one notice each; second run → none, lines kept
fake systemctl '[[ $* == *--user* ]] && exit 0; [[ $* == *--failed* ]] && echo "backup-thing.service loaded failed failed Test"'
fake coredumpctl 'echo "Wed 2026-11-11 15:00:00 +07 4242 1000 1000 SIGSEGV present /usr/bin/crashme 1.0M"'
fake nmcli 'echo portal'; fake docker 'exit 1'; fake xdg-open 'exit 0'
: >"$N"; ORACLE_DISK_ALERT=0 bash "$W"; sleep 1
ck "alert: disk almost full, with the fix" '[[ $(seen "Disk almost full|Disk is [0-9]*% full. Free some space: oracle files") == 1 ]]'
ck "alert: failed service, with the fix" '[[ $(seen "The service backup-thing stopped working. Check it with: oracle doctor") == 1 ]]'
ck "alert: app crash" '[[ $(seen "Crashme quit unexpectedly.|Open it again to carry on.") == 1 ]]'
ck "alert: Wi-Fi sign-in, click opens the browser" '[[ $(seen "-A|default=Open|This Wi-Fi needs a sign-in.") == 1 ]]'
n=$(grep -c . "$N"); ORACLE_DISK_ALERT=0 bash "$W"; sleep 1
ck "second run: no repeats (once a day), dashboard lines kept" '[[ $(grep -c . "$N") == "$n" && $(grep -c . "$S/alerts") == 4 ]]'
ck "wording: sentence case, no exclamation marks" '! grep -q "!" "$N" "$S/alerts"'
fake systemctl 'exit 0'; fake nmcli 'echo full'; fake coredumpctl 'exit 0'; bash "$W"
ck "all fine again: dashboard lines gone" '[[ ! -s $S/alerts ]]'

# idle steps: on AC the battery timers do nothing; on battery dim → off → wake, each once
: >"$T/bright"; export ORACLE_POWER_SUPPLY=$PS; set_b 50 Charging 1
bash "$R/bin/oracle" idle dim battery; ck "idle on AC: battery timer does nothing" '[[ ! -s $T/bright ]]'
set_b 50 Discharging 0; export KBD=1
for s in dim dim off off wake wake; do bash "$R/bin/oracle" idle $s battery; done
ck "idle on battery: dim, keyboard light off, screen off, wake restores, each once" \
  '[[ $(grep -c "^-q -s set 10%" "$T/bright") == 1 && $(grep -c "kbd_backlight -s set 0" "$T/bright") == 1 && $(grep -c "^-q set 0" "$T/bright") == 1 && $(grep -c "^-q -r" "$T/bright") == 1 ]]'
: >"$T/hypr"; HYPRLAND_INSTANCE_SIGNATURE=x bash -c "for s in off off wake; do bash $R/bin/oracle idle \$s; done"
ck "desktop: screen off once and on once (dpms toggles)" '[[ $(grep -c "dpms(\"off\")" "$T/hypr") == 1 && $(grep -c "dpms(\"on\")" "$T/hypr") == 1 ]]'
unset ORACLE_POWER_SUPPLY KBD

# migration: untouched idle + power menu → new; edited copy kept with one line
rm -rf "$HOME/.local/share/oracle"; ln -s "$R" "$HOME/.local/share/oracle"; C=$HOME/.config; mkdir -p "$C/hypr" "$C/fuzzel"
cp "$R/test/fixtures/system/hypridle-v1.conf""$C/hypr/hypridle.conf"; { cat "$R/test/fixtures/system/power-menu-v1.sh"; echo '# mine'; } >"$C/fuzzel/power-menu.sh"
out=$(bash "$R/migrations/1794383700.sh")
ck "migration: untouched idle timers replaced, edited power menu kept, one line" 'cmp -s "$C/hypr/hypridle.conf" "$R/config/hypr/hypridle.conf" && grep -q "# mine" "$C/fuzzel/power-menu.sh" && [[ $(grep -c . <<<"$out") == 1 && $out == *"power-menu.sh is your own version"* ]]'
cp "$R/test/fixtures/system/power-menu-v1.sh""$C/fuzzel/power-menu.sh"; out=$(bash "$R/migrations/1794383700.sh")
ck "migration: untouched power menu replaced, rerun quiet" 'cmp -s "$C/fuzzel/power-menu.sh" "$R/config/fuzzel/power-menu.sh" && [[ -z $out ]]'
fake fuzzel 'echo "$*" >>'"$T"'/fz; cat >>'"$T"'/fz; n=$(grep -c dmenu '"$T"'/fz); [[ $n == 1 ]] && echo Shutdown || echo Cancel'
fake systemctl 'echo "$*" >>'"$T"'/sc'; bash "$C/fuzzel/power-menu.sh"
ck "power menu: Shut Down asks once, Cancel is first, Cancel does nothing" 'grep -q "Shut down now?" "$T/fz" && grep -qx Cancel "$T/fz" && grep -A1 -x Cancel "$T/fz" | grep -qx "Shut Down" && [[ ! -e $T/sc ]]'

((fail)) && echo "system: FAILED" || echo "system ok"
exit $fail
