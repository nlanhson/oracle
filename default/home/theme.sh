# Colors + drawing helpers shared by all widgets. Layout sizes (LW, RW, SW) come from bin/oracle-home.
# shellcheck disable=SC2034  # used by widget files
W=$'\e[38;2;200;200;200m' D=$'\e[38;2;90;90;90m' F=$'\e[38;2;52;52;52m' R=$'\e[38;2;139;46;46m' N=$'\e[0m'
SPARK=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
declare -A ACCENTS=([cyan]=00e5ff [amber]=ffb000 [green]=3ddc84 [purple]=b388ff [white]=e8e8e8) # settings: accent
A=$(sed -n 's/^accent=//p' ~/.config/oracle/settings 2>/dev/null | tail -1) || true; A=${ACCENTS[${A:-cyan}]:-00e5ff}
C=$'\e[38;2;'"$((16#${A:0:2}));$((16#${A:2:2}));$((16#${A:4:2}))m"
rep() { local s; printf -v s "%$2s" ''; printf %s "${s// /$1}"; } # rep <char> <count>
num() { [[ $1 =~ ^[0-9]+$ ]] && ((10#$1 <= 100)); }
title() { printf "${D}── ${W}%s ${D}%s${N}\n" "$1" "$(rep ─ $((RW - ${#1} - 4)))"; }
spark() { # spark <label> <value> <extra> <history...>: scrolling sparkline, oldest left, ends with ▏
  local l=$1 v=$2 x=$3 o='' h; shift 3
  for h; do o+=${SPARK[$((h * 7 / 100))]}; done
  printf "${W}%-12s${F}%s${C}%s${D}▏${W}%8s ${D}%s${N}\n" "$l" "$(rep ▁ $((SW - $#)))" "$o" "$v" "$x"
}
meter() { # meter <0-100|""> <label> <extra>: ━━━━━─────
  num "$1" || { printf "${W}%-12s${F}%s${D}%8s${N}\n" "$2" "$(rep ─ $((SW + 1)))" n/a; return; }
  local f=$(($1 * (SW + 1) / 100))
  printf "${W}%-12s${C}%s${F}%s${W}%7d%% ${D}%s${N}\n" "$2" "$(rep ━ "$f")" "$(rep ─ $((SW + 1 - f)))" "$1" "$3"
}
bar() { # bar <0-100|""> <label>: [=====-----] for things you set
  num "$1" || { printf "${W}%-12s${D}[%s]%8s${N}\n" "$2" "$(rep - $((SW - 1)))" n/a; return; }
  local f=$(($1 * (SW - 1) / 100))
  printf "${W}%-12s${C}[%s${D}%s${C}]${W}%7d%%${N}\n" "$2" "$(rep '=' "$f")" "$(rep - $((SW - 1 - f)))" "$1"
}
key() { # key → KEY = up down left right enter esc tab space backspace or the character
  local k r; IFS= read -rsn1 k || return 1
  case $k in
    $'\e') IFS= read -rsn2 -t 0.02 r; case $r in '[A') KEY=up ;; '[B') KEY=down ;; '[C') KEY=right ;; '[D') KEY=left ;; *) KEY=esc ;; esac ;;
    '') KEY=enter ;; $'\t') KEY=tab ;; ' ') KEY=space ;; $'\x7f') KEY=backspace ;; *) KEY=$k ;;
  esac
}
box() { # box <title> <footer>: LINES[] in an ascii.rest frame, BW wide, top-left at BY;BX
  local t=$1 f=$2 i=0 l
  printf "\e[%d;%dH${D}╭─ ${W}%s ${D}%s╮" "$BY" "$BX" "$t" "$(rep ─ $((BW - ${#t} - 5)))"
  for l in "${LINES[@]}"; do
    ((++i)); printf "\e[%d;%dH${D}│${N} %s\e[%d;%dH${D}│" $((BY + i)) "$BX" "$l" $((BY + i)) $((BX + BW - 1))
  done
  printf "\e[%d;%dH${D}╰%s ${W}%s ${D}─╯${N}" $((BY + i + 1)) "$BX" "$(rep ─ $((BW - ${#f} - 5)))" "$f"
}
