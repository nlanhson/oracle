# Month calendar in the right column, today in cyan.
w_calendar() {
  local r=4 d; d=$(date +%-d)
  while IFS= read -r line; do printf '\e[%d;66H%s' $((r++)) "$line"; done < <(LC_ALL=C cal | sed -E "1s/.*/${C}&${N}/; 2s/.*/${D}&${W}/; 3,\$s/(^| )($d)( |$)/\1${C}\2${W}\3/")
}
