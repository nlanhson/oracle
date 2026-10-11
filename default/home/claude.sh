# Claude Code activity heatmap: last 7 days x 24 h from local logs (replies per hour), refreshed every 60 s.
HEAT='' HEAT_AT=-999
heat() {
  grep -rh --include='*.jsonl' '"type":"assistant"' ~/.claude/projects 2>/dev/null | grep -oE '"timestamp":"[^"]+' | cut -d'"' -f4 |
    date -f - '+%F %-H' 2>/dev/null | LC_ALL=C.UTF-8 awk -v D="$D" -v C="$C" -v W="$W" -v F="$F" -v N="$N" '
    BEGIN { split("· ░ ▒ ▓ █", g, " ")
      for (i = 6; i >= 0; i--) { cmd = "LC_ALL=C date -d \"-" i " day\" \"+%F %a\""; cmd | getline l; close(cmd); split(l, a, " "); day[6-i] = a[1]; name[6-i] = tolower(a[2]) } }
    { n[$1, $2]++; t++; if (n[$1, $2] > max) max = n[$1, $2] }
    END { printf "%s%12s%-12s%-12s%-12s%s%s\n", D, "", "12am", "6am", "12pm", "6pm", N
      for (r = 0; r < 7; r++) { printf "%s%-12s", D, name[r]
        for (h = 0; h < 24; h++) { v = n[day[r], h]; k = max && v ? int((v * 4 + max - 1) / max) : 0; printf "%s%s ", k ? C : F, g[k + 1] }
        printf "%s\n", N }
      printf "\n%s%12s%d replies in 7 days    less %s·%s ░ ▒ ▓ █ %smore%s\n", D, "", t, F, C, D, N }'
}
w_claude() { ((SECONDS - HEAT_AT >= 60)) && { HEAT=$(heat); HEAT_AT=$SECONDS; }; title claude; printf '%s\n\n' "$HEAT"; }
