# Server apps: this laptop only (127.0.0.1), the phone gets in through tailscale serve. Only changes lines you never edited.
# Phone: Immich app → sign out, log in with the https://….ts.net address printed below (the old http://100.x.x.x:2283 stops working).
f=$HOME/docker/immich/docker-compose.yml; [[ ! -f $f ]] || sed -i "s|^      - '2283:2283'$|      - '127.0.0.1:2283:2283' # this laptop only; phone: tailscale serve|" "$f"
f=$HOME/dockge/compose.yaml; [[ ! -f $f ]] || sed -i 's|^      - "5001:5001"$|      - "127.0.0.1:5001:5001" # this laptop only; phone: tailscale serve :8443|' "$f"
[[ -f $HOME/dockge/compose.yaml || -f $HOME/docker/immich/docker-compose.yml ]] || exit 0
bash "$HOME/.local/share/oracle/server/server.sh" start
