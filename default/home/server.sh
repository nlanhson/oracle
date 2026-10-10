# Home server containers, tailscale, wifi.
svc() { # svc <label> <container>
  local st; st=$(docker inspect -f '{{.State.Status}}' "$2" 2>/dev/null)
  if [[ $st == running ]]; then printf "  ${W}%-10s${C}● up${N}  " "$1"; else printf "  ${W}%-10s${R}● ${st:-off}${N}  " "$1"; fi
}
w_server() {
  svc immich immich_server; svc dockge dockge; echo
  svc vpn-exit gluetun; printf "  ${W}%-10s${C}%s${N}\n" tailscale "$(tailscale ip -4 2>/dev/null | head -1 || true)"
  printf "  ${W}%-10s${C}%s${N}\n\n" wifi "$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')"
}
