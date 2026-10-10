#!/usr/bin/env bash
# Oracle ISO = archiso releng (copied at build time) + installer autostart on tty1. Needs docker (privileged).
# iso/build.sh <outdir> → oracle-YYYY.MM.DD-x86_64.iso + .sha256. install.sh/archinstall.json inside = fallback only;
# at install time install.sh fetches the newest from GitHub, so the ISO rarely needs a rebuild.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$(realpath -m "${1:?usage: iso/build.sh <outdir>}")
mkdir -p "$OUT"
docker run --rm --privileged -e OWNER="$(id -u):$(id -g)" -v "$ROOT:/repo:ro" -v "$OUT:/out" archlinux:latest bash -euo pipefail -c '
pacman -Syu --noconfirm --needed archiso >/dev/null
P=/tmp/oracle; cp -r /usr/share/archiso/configs/releng "$P"
sed -i -e "s/^iso_name=.*/iso_name=\"oracle\"/" -e "s/^iso_label=\"ARCH_/iso_label=\"ORACLE_/" \
  -e "s|^iso_publisher=.*|iso_publisher=\"Oracle <https://github.com/nlanhson/oracle>\"|" \
  -e "s/^iso_application=.*/iso_application=\"Oracle installer\"/" "$P/profiledef.sh"
grep -rl "Arch Linux install medium" "$P"/{efiboot,syslinux,grub} | xargs sed -i "s/Arch Linux install medium/Oracle installer/"
echo jq >>"$P/packages.x86_64"
install -Dm644 -t "$P/airootfs/root/oracle" /repo/install.sh /repo/archinstall.json
echo "[[ \$(tty) == /dev/tty1 && ! -e /tmp/startup_script ]] && bash /root/oracle/install.sh" >>"$P/airootfs/root/.zlogin"
mkarchiso -w /tmp/work -o /out "$P"
cd /out && for i in oracle-*.iso; do sha256sum "$i" >"$i.sha256"; done
chown "$OWNER" /out/oracle-*'
