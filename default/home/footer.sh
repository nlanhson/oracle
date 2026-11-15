# Bottom links. FOOT = the clickable words, in order (bin/oracle-home maps a click to the key in brackets).
w_footer() {
  local n; n=$(sed -n 's/^packages=//p' ~/.local/state/oracle/updates 2>/dev/null)
  [[ $(sed -n 's/^oracle=//p' ~/.local/state/oracle/updates 2>/dev/null) == [1-9]* ]] && n=$((${n:-0} + 1)) # a newer Oracle counts as one
  ((${n:-0})) || n=''
  FOOT=('[g]ui' '[f]iles' '[s]ettings' "[u]pdate${n:+ $n}" '[m]anual')
  printf "${C}[g]${W}ui  ${C}[f]${W}iles  ${C}[s]${W}ettings  ${C}[u]${W}pdate${D}${n:+ $n}  ${C}[m]${W}anual  ${C}[alt+1-4]${W} workspaces${N}\n"
}
