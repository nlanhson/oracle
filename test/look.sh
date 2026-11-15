#!/usr/bin/env bash
# One look, no VM, nothing outside a temp HOME: tokens → generated files, one token edit changes them all, the migration swaps
# untouched old copies and leaves edited ones. Old copies = test/fixtures/look/. bash test/look.sh
R=$(cd "$(dirname "$0")/.." && pwd); T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export HOME=$T/home; mkdir -p "$HOME/.local/share" "$T/bin"; ln -s "$R" "$HOME/.local/share/oracle"
for c in pkill tmux swaync-client; do printf '#!/bin/sh\nexit 0\n' >"$T/bin/$c"; chmod +x "$T/bin/$c"; done; PATH=$T/bin:$PATH
O=$R/bin/oracle L=$HOME/.config/oracle/look F=$R/test/fixtures/look fail=0
ck() { if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fail=1; fi; }
bash "$O" look
ck "oracle look writes colors.css launcher.css hyprlock.conf tokens.lua" '[[ -s $L/colors.css && -s $L/launcher.css && -s $L/hyprlock.conf && -s $L/tokens.lua ]]'
ck "tokens.lua is valid Lua" '! command -v lua >/dev/null || LL=$L/tokens.lua lua -e "os.exit(assert(loadfile(os.getenv(\"LL\")))().r_l == 14 and 0 or 1)" </dev/null'
ck "launcher.css has no unfilled %token% left" '! grep -qE "%[a-z_]+%px" "$L/launcher.css"'
ck "tokens.json is valid JSON with colours, radii, font and accent (the Control Center reads it)" '[[ $(python3 -c "import json,sys; t=json.load(open(sys.argv[1])); print(t[\"r_l\"], t[\"font_ui\"], t[\"accent\"][0], t[\"bright\"])" "$L/tokens.json") == "14 Inter # #ffffff" ]]'
i=$(stat -c %i "$L/colors.css"); bash "$O" look
ck "second run writes nothing (files unchanged)" '[[ $i == $(stat -c %i "$L/colors.css") && -z $(ls "$L"/*.new 2>/dev/null) ]]'
printf 'text=ff00ff\nr_l=20\n' >"$HOME/.config/oracle/tokens"; bash "$O" look
ck "one token edit changes every generated file" 'grep -qi ff00ff "$L/colors.css" && grep -q "border-radius: 20px" "$L/launcher.css" && grep -qi ff00ff "$L/hyprlock.conf" && grep -qi ff00ff "$L/tokens.lua"'
ck "corner token reaches launcher, lock and Hyprland tokens" 'grep -q "border-radius: 20px" "$L/launcher.css" && grep -q "r_l = 20" "$L/hyprlock.conf" && grep -q "r_l = 20" "$L/tokens.lua"'
rm "$HOME/.config/oracle/tokens"; bash "$O" look
C=$HOME/.config; mkdir -p "$C/waybar" "$C/fuzzel" "$C/swaync" "$C/hypr"
cp "$F/waybar-style.css" "$C/waybar/style.css"; cp "$F/fuzzel-v1.ini" "$C/fuzzel/fuzzel.ini"; cp "$F/swaync-style.css" "$C/swaync/style.css"
{ cat "$F/hyprlock-v2.conf"; echo '# mine'; } >"$C/hypr/hyprlock.conf"; cp "$C/hypr/hyprlock.conf" "$T/lock.mine"
printf '"exec": "date +'"'"'%%I:%%M %%a,%%d/%%m'"'"'",/*Only Time: date '"'"'+%%I:%%M %%p'"'"'*/\n' >"$C/waybar/config.jsonc"
out=$(bash "$R/migrations/1794366900.sh" 2>&1)
ck "migration: untouched bar and notifications become stubs" 'grep -q "$HOME/.local/share/oracle/default/waybar/style.css" "$C/waybar/style.css" && grep -q "default/swaync/style.css" "$C/swaync/style.css" && ! grep -q @HOME@ "$C/waybar/style.css" "$C/fuzzel/fuzzel.ini"'
ck "migration: edited lock screen untouched, one plain line says so" 'cmp -s "$C/hypr/hyprlock.conf" "$T/lock.mine" && [[ $out == *"hypr/hyprlock.conf keeps your own look"* && $(wc -l <<<"$out") == 1 ]]'
ck "migration: bar clock now 12 hours with AM/PM" 'grep -q "%-I:%M %p" "$C/waybar/config.jsonc"'
cp "$F/fuzzel-v2.ini" "$C/fuzzel/fuzzel.ini"; cp "$F/hyprlock-v1.conf" "$C/hypr/hyprlock.conf"; out=$(bash "$R/migrations/1794366900.sh" 2>&1)
ck "migration: second Oracle version of a file also recognised, rerun is quiet" 'grep -q "^source = $HOME/.config/oracle/look" "$C/hypr/hyprlock.conf" && [[ -z $out ]]'
cp "$F/power-menu-v1.sh" "$C/fuzzel/power-menu.sh"
bash "$R/migrations/1794390000.sh"
ck "migration: old power menu script opens the launcher" 'grep -q "oracle launcher power" "$C/fuzzel/power-menu.sh"'
echo '# mine' >>"$C/fuzzel/power-menu.sh"; bash "$R/migrations/1794390000.sh"
ck "migration: an edited power menu script is left alone" 'grep -q "# mine" "$C/fuzzel/power-menu.sh"'
((fail)) && echo "look: FAILED" || echo "look ok"
exit $fail
