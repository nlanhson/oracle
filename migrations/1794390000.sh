# Launcher: Super+Space is now Oracle's own search box (apps, oracle commands, sums, files, power), not fuzzel. The old power menu script (still run by the bar's
# power button) now opens the launcher's power menu. fuzzel stays installed (nothing deleted); remove it any time: sudo pacman -Rns fuzzel
C=$HOME/.config
P=$C/fuzzel/power-menu.sh # untouched old copy → one line that opens the new power menu (an old bar still points at this path)
if [[ -f $P ]] && [[ $(sha256sum "$P" | cut -d' ' -f1) == 192ebc62d24daa7e229160d9251507546522565305aa9a20db0f8353dead9d70 ]]; then
  printf '#!/bin/bash\nexec oracle launcher power\n' >"$P"
fi
pkill -x fuzzel || true
