#!/usr/bin/env bash
# Control panel, no VM, temp HOME: config.json validates against swaync's own schema, bar config is valid, `oracle panel` buttons
# change the real settings (fake nmcli/bluetoothctl/wpctl/swaync-client), migration swaps untouched old copies only. bash test/panel.sh
R=$(cd "$(dirname "$0")/.." && pwd); T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export HOME=$T/home; mkdir -p "$HOME/.local/share" "$T/bin" "$T/st"; ln -s "$R" "$HOME/.local/share/oracle"
fake() { printf '#!/bin/sh\n%s\n' "$2" >"$T/bin/$1"; chmod +x "$T/bin/$1"; }
for c in pkill tmux; do fake $c 'exit 0'; done
fake nmcli 'if [ "$1 $2" = "radio wifi" ] && [ -n "$3" ]; then echo $3 >"'$T'/st/wifi"; else [ "$(cat "'$T'/st/wifi" 2>/dev/null)" = off ] && echo disabled || echo enabled; fi'
fake bluetoothctl 'if [ "$1" = power ]; then echo $2 >"'$T'/st/bt"; else echo "Powered: $([ "$(cat "'$T'/st/bt" 2>/dev/null)" = off ] && echo no || echo yes)"; fi'
fake wpctl 'if [ "$1" = set-mute ]; then echo $3 >"'$T'/st/mute"; else echo "Volume: 0.40$([ "$(cat "'$T'/st/mute" 2>/dev/null)" = 1 ] && echo " [MUTED]")"; fi'
fake swaync-client 'case $1 in -dn) echo true >"'$T'/st/dnd";; -df) echo false >"'$T'/st/dnd";; -D) cat "'$T'/st/dnd" 2>/dev/null || echo false;; esac'
PATH=$T/bin:$PATH O=$R/bin/oracle F=$R/test/fixtures/panel fail=0
ck() { if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fail=1; fi; }
S=/etc/xdg/swaync/configSchema.json
if [[ -f $S ]] && python3 -c 'import jsonschema' 2>/dev/null; then
  ck "swaync config.json validates against swaync's schema" 'python3 -c "import json,sys,jsonschema; jsonschema.validate(json.load(open(sys.argv[1])), json.load(open(sys.argv[2])))" "$R/config/swaync/config.json" $S'
else echo "SKIP schema check (no swaync schema or python-jsonschema here)"; fi
ck "swaync config.json has no example or junk entries" '! grep -q "example" "$R/config/swaync/config.json"'
for t in wifi bt dnd night mute; do
  ck "panel $t: off then on changes the real state" '[[ $(bash $O panel $t false; bash $O panel $t) == false && $(bash $O panel $t true; bash $O panel $t) == true ]]'
done
ck "panel night light writes the nightlight setting" '[[ $(bash $O panel night true; bash $O get nightlight) == always && $(bash $O panel night false; bash $O get nightlight off) == off ]]'
mkdir -p "$T/ps/BAT0"; echo 64 >"$T/ps/BAT0/capacity"; echo Discharging >"$T/ps/BAT0/status"
st_() { ORACLE_PS=$T/ps bash $O panel state; }
ck "panel state: one key=value per line with the real settings" '[[ $(bash $O panel wifi false; st_) == *wifi=off* && $(bash $O panel dnd true; st_) == *dnd=true* && $(st_) == *bat=64* && $(st_) == *batstate=Discharging* ]]'
ck "panel state: night light cycles off → evening → always → off" '[[ $(bash $O panel night false; bash $O panel night cycle; bash $O get nightlight) == evening && $(bash $O panel night cycle; bash $O get nightlight) == always && $(bash $O panel night cycle; bash $O get nightlight off) == off ]]'
Q=$R/default/quickshell
ck "Control Center files exist, namespace oracle-panel, IPC target panel" '[[ -f $Q/shell.qml && -f $Q/Tokens.qml && -f $Q/Slider.qml ]] && grep -q "oracle-panel" $Q/shell.qml && grep -q "target: \"panel\"" $Q/shell.qml'
ck "bar: control-centre icon opens the Control Center, clock opens the Notification Center" 'grep -A14 "^\"custom/panel\"" $R/config/waybar/config.jsonc | grep -q "\"on-click\": \"oracle panel\"" && grep -A5 "^\"custom/date\"" $R/config/waybar/config.jsonc | grep -q "swaync-client -t -sw"'
ck "Notification Center config: only the title (Clear All) and notifications widgets" '[[ $(python3 -c "import json,sys; print(\",\".join(json.load(open(sys.argv[1]))[\"widgets\"]))" "$R/config/swaync/config.json") == title,notifications ]]'
C=$HOME/.config; mkdir -p "$C/swaync" "$C/waybar"
cp "$F/swaync-v1.json" "$C/swaync/config.json"
out=$(bash "$R/migrations/1794453300.sh" 2>&1)
ck "migration: untouched old configs become the control panel ones" 'cmp -s "$C/swaync/config.json" "$R/config/swaync/config.json" && [[ -z $out ]]'
echo '{ "mine": true }' >"$C/swaync/config.json"; cp "$C/swaync/config.json" "$T/mine"
out=$(bash "$R/migrations/1794453300.sh" 2>&1)
ck "migration: edited config kept, one plain line says so" 'cmp -s "$C/swaync/config.json" "$T/mine" && [[ $out == *"swaync/config.json keeps your own version"* && $(wc -l <<<"$out") == 1 ]]'
cp "$F/swaync-v2.json" "$C/swaync/config.json"; out=$(bash "$R/migrations/1794655400.sh" 2>&1)
ck "migration: untouched previous notification config becomes the new one (empty line at the top, list as tall as its cards)" 'cmp -s "$C/swaync/config.json" "$R/config/swaync/config.json" && [[ -z $out ]] && grep -q "\"control-center-height\": -1" "$C/swaync/config.json" && grep -q "\"vexpand\": false" "$C/swaync/config.json"'
echo '{ "control-center-height": 640, "mine": true }' >"$C/swaync/config.json"; cp "$C/swaync/config.json" "$T/mine"; out=$(bash "$R/migrations/1794655400.sh" 2>&1)
ck "migration: edited notification config kept, one plain line says so" 'cmp -s "$C/swaync/config.json" "$T/mine" && [[ $out == *"keeps your own version"* && $(wc -l <<<"$out") == 1 ]]'
ck "Notification Center style: the empty line takes back the hidden picture space" 'grep -q "placeholder image.*margin: 0 0 -108px" "$R/default/swaync/style.css"'
cp "$F/waybar-v1.jsonc" "$C/waybar/config.jsonc"; bash "$R/migrations/1794500000.sh"
ck "migration: untouched previous bar config becomes the new one (no laptop-screen button, mpris click)" '! grep -q custom/display "$C/waybar/config.jsonc" && grep -q "oracle panel media" "$C/waybar/config.jsonc"'
echo '{ "custom/display": 1 }' >"$C/waybar/config.jsonc"; out=$(bash "$R/migrations/1794500000.sh" 2>&1)
ck "migration: edited bar config kept, one plain line says so" 'grep -q custom/display "$C/waybar/config.jsonc" && [[ $out == *"keeps your own version"* && $(wc -l <<<"$out") == 1 ]]'
fake ghostty 'echo ghostty "$@" >"'$T'/st/ran"'; fake airctl 'echo airctl >"'$T'/st/ran"'; fake nmcli_ 'true'
ck "panel: Wi-Fi row opens airctl when installed" 'rm -f $T/st/ran; bash $O panel settings network; sleep 0.5; [[ $(cat $T/st/ran) == airctl ]]'
mv "$T/bin/airctl" "$T/bin/airctl.off"
ck "panel: Wi-Fi row falls back to the terminal list without airctl" 'rm -f $T/st/ran; bash $O panel settings network; sleep 0.5; [[ $(cat $T/st/ran) == *"oracle settings network"* ]]'
((fail)) && echo "panel: FAILED" || echo "panel ok"
exit $fail
