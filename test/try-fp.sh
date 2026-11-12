#!/usr/bin/env bash
# Fingerprint of everything `oracle try back` must put back exactly. Prints sections; compare two runs with diff. Used by test/vm.sh try (runs inside the VM).
S=$HOME/.local/state/oracle
sums() { # sums <dir> [find prune names…]: mode + sha256 (files) or target (links) of everything below <dir>
  local d=$1; shift; [[ -e $d || -L $d ]] || { echo "(absent) $d"; return; }
  ( cd "$d" && find . "${@}" \( -type f -o -type l \) -printf '%p\t%m\t%y\t%l\n' | LC_ALL=C sort | while IFS=$'\t' read -r p m y l; do
      if [[ $y == l ]]; then echo "$p $m -> $l"; else echo "$p $m $(sha256sum "$p" | cut -c1-16)"; fi; done )
}
echo "## ~/.config"; sums "$HOME/.config" \( -path ./dconf -o -path ./pulse -o -iname '*cache*' -o -name 'Brave*' -o -name 'chrom*' \) -prune -o
echo "## ~/.local/state/oracle (migration marks, settings state; not try/mode/open)"; sums "$S" \( -path ./try -o -path ./mode -o -path ./open \) -prune -o
echo "## migration marks"; ls -1 "$S/migrations" 2>/dev/null | wc -l
echo "## shell files + icon theme"; for f in .zshrc .zprofile .bash_profile .bashrc; do sums "$HOME/$f"; done; ( cd "$HOME/.local/share/icons" 2>/dev/null && sums Oracle ) || echo "(no icon theme)"
echo "## gsettings"; for k in font-name monospace-font-name icon-theme color-scheme accent-color cursor-theme cursor-size; do echo "$k=$(dconf read /org/gnome/desktop/interface/$k 2>/dev/null)"; done
echo "## server files (never part of try/back)"; for f in "$HOME"/dockge/compose.yaml "$HOME"/docker/*/compose.y*ml "$HOME"/docker/*/.env; do [[ -f $f ]] && echo "$f $(sha256sum "$f" | cut -c1-16)"; done
echo "## packages (pacman -Qqe)"; pacman -Qqe | sort
echo "## package count (all)"; pacman -Qq | wc -l
echo "## system files"; sudo -n true 2>/dev/null && SU=sudo || SU=
for d in /etc/systemd/system /etc/systemd/logind.conf.d /etc/sysctl.d /etc/udev/rules.d /etc/limine-entry-tool.d /etc/oracle /etc/default/limine /etc/mkinitcpio.conf.d /etc/snapper/configs /usr/local/bin /etc/pacman.d/hooks /etc/xdg; do
  $SU find "$d" \( -type f -o -type l \) -printf '%p\t%m\t%y\t%l\n' 2>/dev/null | LC_ALL=C sort | while IFS=$'\t' read -r p m y l; do
    if [[ $y == l ]]; then echo "$p $m -> $l"; else echo "$p $m $($SU sha256sum "$p" | cut -c1-16)"; fi; done
done
echo "## units"; for u in $(systemctl list-unit-files --no-legend 2>/dev/null | awk '/oracle|getty@|snapper|limine|docker|tailscale|watch/{print $1}' | sort); do echo "$u $(systemctl is-enabled "$u" 2>/dev/null)"; done
echo "## boot"; sed 's/BOOT_IMAGE=[^ ]* //; s/root=[^ ]*//; s/rootflags=[^ ]*//' /proc/cmdline
$SU sed -n '1,/^\//p' /boot/limine.conf 2>/dev/null | head -n 30
echo "## kernel files on /boot"; $SU find /boot -maxdepth 2 -type f \( -name 'vmlinuz*' -o -name 'initramfs*' -o -name '*.efi' \) -printf '%p %s\n' 2>/dev/null | sort
