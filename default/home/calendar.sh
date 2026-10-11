# Month calendar under the clock, 32 wide like the clock, today as [11] (brackets take the spaces around it).
w_calendar() {
  local first days today d j=0 l=' ' cut=0 line pad t
  first=$(date -d "$(date +%Y-%m-01)" +%w) days=$(date -d "$(date +%Y-%m-01) +1 month -1 day" +%-d) today=$(date +%-d)
  printf -v pad "%$(((LW - 33) / 2))s" ''
  t=$(LC_ALL=C date '+%B %Y'); printf "%s ${C}%*s${N}\n\n" "$pad" $(((32 + ${#t}) / 2)) "$t"
  printf "%s ${D}Su   Mo   Tu   We   Th   Fr   Sa${N}\n" "$pad"
  line=$pad$W
  for ((d = 1 - first; d <= days; d++)); do
    ((cut)) && l=${l:1}; cut=0
    if ((d < 1)); then line+="$l  "
    elif ((d == today)); then ((d > 9)) && l=${l:1}; line+="$l${C}[$d]$W"; cut=1
    else printf -v t '%2d' "$d"; line+="$l$t"; fi
    l='   '
    if ((++j % 7 == 0)); then printf '%s\n' "$line"; line=$pad$W l=' ' cut=0; fi
  done
  ((j % 7)) && printf '%s\n' "$line"
  printf "${N}"
}
