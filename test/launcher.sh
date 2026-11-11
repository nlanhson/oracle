#!/usr/bin/env bash
# Launcher ranking, no screen: 20 queries → the expected top row (kind + title), through `oracle-launcher --query`.
# Fake apps (test/fixtures/launcher) and a fake home with a few files. bash test/launcher.sh
R=$(cd "$(dirname "$0")/.." && pwd); T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export HOME=$T/home XDG_DATA_DIRS=$R/test/fixtures/launcher ORACLE_LAUNCHER_ROOT=$T/home
mkdir -p "$HOME/Documents" "$HOME/Downloads" "$HOME/.cache" "$HOME/Pictures/Trip"
touch "$HOME/Documents/Tax-2026.pdf" "$HOME/Downloads/holiday-photos.zip" "$HOME/Documents/ghost-recipes.md" "$HOME/.cache/tax-hidden.txt" "$HOME/Pictures/Trip/IMG_0042.jpg"
fail=0
top() { python3 "$R/bin/oracle-launcher" --query "$1" | head -1; }
ck() { local got; got=$(top "$1"); if [[ $got == "$2"* ]]; then echo "PASS '$1' → ${got//$'\t'/ | }"; else echo "FAIL '$1' → ${got//$'\t'/ | } (wanted $2)"; fail=1; fi; }
T_=$'\t'
ck gho "app${T_}Ghostty"
ck ghostty "app${T_}Ghostty"
ck term "app${T_}Ghostty"
ck brave "app${T_}Brave Origin"
ck browser "app${T_}Brave Origin"
ck files "app${T_}Files"
ck mouse "app${T_}Mousepad"
ck btop "app${T_}btop++"
ck image "app${T_}Loupe"
ck volume "app${T_}Volume Control"
ck upd "cmd${T_}oracle update"
ck doctor "cmd${T_}oracle doctor"
ck rollb "cmd${T_}oracle rollback"
ck "12*7" "sum${T_}84"
ck "(3+4)*2" "sum${T_}14"
ck "2^10" "sum${T_}1024"
ck "10/4" "sum${T_}2.5"
ck lock "power${T_}Lock"
ck shut "power${T_}Shut Down"
ck restart "power${T_}Restart"
ck tax "file${T_}Tax-2026.pdf"
ck IMG_00 "file${T_}IMG_0042.jpg"
ck sleep "power${T_}Sleep"
hid=$(python3 "$R/bin/oracle-launcher" --query tax-hidden); [[ -z $hid ]] && echo "PASS hidden folders are not searched" || { echo "FAIL hidden file found: $hid"; fail=1; }
n=$(python3 "$R/bin/oracle-launcher" --query 2024); [[ -z $n ]] && echo "PASS a bare number is not a sum" || { echo "FAIL bare number: $n"; fail=1; }
((fail)) && echo "launcher: FAILED" || echo "launcher ok"
exit $fail
