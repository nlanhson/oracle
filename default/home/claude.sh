# Claude Code activity heatmap: last 7 days x 24 h from local logs, refreshed every 60 s.
HEAT='' HEAT_AT=-999
heat() {
  grep -rh --include='*.jsonl' '"type":"assistant"' ~/.claude/projects 2>/dev/null | grep -oE '"timestamp":"[^"]+' | cut -d'"' -f4 |
    date -f - '+%F %-H' 2>/dev/null | LC_ALL=C.UTF-8 awk -v cells=' ·░▒▓█' -v D="$D" -v C="$C" -v W="$W" -v N="$N" '
    BEGIN { for (i = 6; i >= 0; i--) { cmd = "LC_ALL=C date -d \"-" i " day\" \"+%F %a\""; cmd | getline l; close(cmd); split(l, a, " "); day[6-i] = a[1]; name[6-i] = a[2] } }
    { n[$1, $2]++; if (n[$1, $2] > max) max = n[$1, $2] }
    END { printf "  %sclaude%s    %s0     6     12    18   23%s\n", W, N, D, N
      for (r = 0; r < 7; r++) { printf "  %s%-9s%s", D, name[r], C
        for (h = 0; h < 24; h++) { v = n[day[r], h]; k = max ? int((v * 5 + max - 1) / max) : 0; printf "%s", substr(cells, k + 1, 1) }
        printf "%s\n", N } }'
}
w_claude() { ((SECONDS - HEAT_AT >= 60)) && { HEAT=$(heat); HEAT_AT=$SECONDS; }; printf '%s\n\n' "$HEAT"; }
