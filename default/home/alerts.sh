# Plain-word alerts (oracle watch, battery watcher) at the top of the right column. Nothing at all when all is well.
w_alerts() {
  local l n=0
  while IFS= read -r l; do [[ -n $l ]] && ((n++ < 3)) && printf "${R}!${W} %s${N}\n" "${l:0:$((RW - 2))}"; done < <(cat /run/oracle/battery ~/.local/state/oracle/alerts 2>/dev/null)
  ((n)) && echo; return 0
}
