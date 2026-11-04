# Firewall on: nothing gets in except Tailscale (apps listen on this laptop only, the phone uses tailscale serve). LLMNR off.
sudo pacman -S --needed --noconfirm ufw
sudo bash "$HOME/.local/share/oracle/system/oracle-firewall" --now
