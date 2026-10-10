# Colors + drawing helpers shared by all widgets.
# shellcheck disable=SC2034  # used by widget files
C=$'\e[38;2;0;229;255m' W=$'\e[38;2;200;200;200m' D=$'\e[38;2;90;90;90m' R=$'\e[38;2;139;46;46m' N=$'\e[0m'
SPARK=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █) EQ='==========' DASH='----------'
bar() { # bar <0-100|""> <label> <suffix>
  local p=$1 f
  if [[ ! $p =~ ^[0-9]+$ ]]; then printf "  ${W}%-9s${D}[----------]  n/a${N}\n" "$2"; return; fi
  ((p > 100)) && p=100; f=$((p / 10))
  printf "  ${W}%-9s${C}[%s${D}%s${C}]${W} %3d%%${D} %s${N}\n" "$2" "${EQ:0:f}" "${DASH:0:10-f}" "$p" "$3"
}
spark() { local o='' v; for v; do o+=${SPARK[$((v * 7 / 100))]}; done; printf %s "$o"; }
rule() { printf "  ${D}%s${N}\n" "──────────────────────────────────────────────────────────"; }
