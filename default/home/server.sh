# Home server apps, tailscale, wifi.
svc() { # svc <label> <container>
  local st; st=$(docker inspect -f '{{.State.Status}}' "$2" 2>/dev/null)
  if [[ $st == running ]]; then printf "${W}%-12s${C}● up     ${N}" "$1"; else printf "${W}%-12s${R}● %-7s${N}" "$1" "${st:-off}"; fi
}
w_server() {
  local ip wifi
  title server
  svc immich immich_server; svc dockge dockge; svc vpn-exit gluetun; echo
  ip=$(tailscale ip -4 2>/dev/null | head -1) wifi=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')
  printf "${W}%-12s${C}%-30s${W}%-12s${C}%s${N}\n\n" tailscale "${ip:-off}" wifi "${wifi:-off}"
}
