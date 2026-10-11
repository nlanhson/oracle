# Month calendar under the clock, today highlighted.
w_calendar() {
  local d pad; d=$(date +%-d); printf -v pad "%$(((LW - 20) / 2))s" ''
  LC_ALL=C cal | sed -E "/^ *$/d; s/^/$pad/; 1s/.*/${C}&${N}/; 2s/.*/${D}&${W}/; 3,\$s/ ($d)( |$)/${C}[\1]${W}/"
  printf "${N}"
}
