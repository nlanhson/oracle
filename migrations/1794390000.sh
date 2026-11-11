# Launcher: Super+Space is now Oracle's own search box (apps, oracle commands, sums, files, power), not fuzzel. The old power menu script and the
# bar's power button move to it. fuzzel stays installed (nothing deleted); remove it any time: sudo pacman -Rns fuzzel
C=$HOME/.config
P=$C/fuzzel/power-menu.sh # untouched old copy → one line that opens the new power menu (an old bar still points at this path)
if [[ -f $P ]] && [[ $(sha256sum "$P" | cut -d' ' -f1) == 192ebc62d24daa7e229160d9251507546522565305aa9a20db0f8353dead9d70 ]]; then
  printf '#!/bin/bash\nexec oracle launcher power\n' >"$P"
fi
W=$C/waybar/config.jsonc # power button: only if the line is still Oracle's
[[ ! -f $W ]] || sed -i 's|"on-click": "bash ~/.config/fuzzel/power-menu.sh"|"on-click": "oracle launcher power"|' "$W"
pkill -x fuzzel || true
