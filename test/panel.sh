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
ck "bar config is valid JSON (comments removed)" 'python3 -c "import re,json,sys; t=re.sub(r\"/\*.*?\*/\",\"\",open(sys.argv[1]).read(),flags=re.S); json.loads(t)" "$R/config/waybar/config.jsonc"'
for t in wifi bt dnd night mute; do
  ck "panel $t: off then on changes the real state" '[[ $(bash $O panel $t false; bash $O panel $t) == false && $(bash $O panel $t true; bash $O panel $t) == true ]]'
done
ck "panel night light writes the nightlight setting" '[[ $(bash $O panel night true; bash $O get nightlight) == always && $(bash $O panel night false; bash $O get nightlight off) == off ]]'
C=$HOME/.config; mkdir -p "$C/swaync" "$C/waybar"
cp "$F/swaync-v1.json" "$C/swaync/config.json"; cp "$F/waybar-v2.jsonc" "$C/waybar/config.jsonc"
out=$(bash "$R/migrations/1794453300.sh" 2>&1)
ck "migration: untouched old configs become the control panel ones" 'cmp -s "$C/swaync/config.json" "$R/config/swaync/config.json" && cmp -s "$C/waybar/config.jsonc" "$R/config/waybar/config.jsonc" && [[ -z $out ]]'
echo '{ "mine": true }' >"$C/swaync/config.json"; cp "$C/swaync/config.json" "$T/mine"; cp "$F/waybar-v1.jsonc" "$C/waybar/config.jsonc"
out=$(bash "$R/migrations/1794453300.sh" 2>&1)
ck "migration: edited config kept, one plain line says so; first Oracle bar config recognised" 'cmp -s "$C/swaync/config.json" "$T/mine" && [[ $out == *"swaync/config.json keeps your own version"* && $(wc -l <<<"$out") == 1 ]] && cmp -s "$C/waybar/config.jsonc" "$R/config/waybar/config.jsonc"'
((fail)) && echo "panel: FAILED" || echo "panel ok"
exit $fail
