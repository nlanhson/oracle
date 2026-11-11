#!/usr/bin/env bash
# VM test, needs only docker + /dev/kvm. Boot ISO → installer, one pass (archinstall + Oracle in chroot + TPM) → reboot,
# expect NO disk password → checks. Files in $VM_DIR. Log: $VM_DIR/serial.log.
# test/vm.sh          stock Arch ISO, curl install.sh | bash, NVMe of G14 size (sparse)
# test/vm.sh iso      our ISO (iso/build.sh → $VM_DIR, reused; rm it to rebuild), its own installer copy, 64G NVMe
# test/vm.sh oracle   reuse the installed disk from the last run, checks only
set -euo pipefail
if [[ ! -f /.dockerenv ]]; then
  ROOT=$(cd "$(dirname "$0")/.." && pwd)
  VM=${VM_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oracle-vm}
  mkdir -p "$VM"
  [[ ${1:-} != iso ]] || compgen -G "$VM/oracle-*.iso" >/dev/null || "$ROOT/iso/build.sh" "$VM"
  exec docker run --rm -i --device /dev/kvm -e OWNER="$(id -u):$(id -g)" -v "$ROOT:/repo:ro" -v "$VM:/vm" archlinux:latest bash /repo/test/vm.sh "$@"
fi
trap 'chown -R "$OWNER" /vm' EXIT
cd /vm && mkdir -p pkg && : >serial.log
echo "== container: qemu, swtpm"
pacman -Syu --noconfirm --needed --cachedir /vm/pkg qemu-base qemu-hw-display-virtio-{vga,gpu} edk2-ovmf swtpm python git >/dev/null

MODE=${1:-arch} ISO=''
if [[ $MODE != oracle ]]; then
  if [[ $MODE == iso ]]; then
    ISO=$(ls -t /vm/oracle-*.iso | head -1) SIZE=64G
  else
    URL=https://geo.mirror.pkgbuild.com/iso/latest ISO=/vm/archlinux-x86_64.iso SIZE=512110190592 # = G14 nvme0n1
    curl -fsSL $URL/sha256sums.txt | grep ' archlinux-x86_64.iso$' >iso.sha256
    sha256sum -c --status iso.sha256 2>/dev/null || { curl -fsSL -o archlinux-x86_64.iso $URL/archlinux-x86_64.iso; sha256sum -c iso.sha256; }
  fi
  echo "== $ISO"
  rm -rf boot tpm arch.* && mkdir boot tpm && bsdtar -xf "$ISO" -C boot arch/boot/x86_64 loader/entries
  cp /usr/share/edk2/x64/OVMF_VARS.4m.fd vars.fd
  qemu-img create -qf qcow2 disk.qcow2 $SIZE
else
  cp arch.vars.fd vars.fd && rm -rf tpm && cp -a arch.tpm tpm
  qemu-img create -qf qcow2 -b arch.qcow2 -F qcow2 disk.qcow2
fi

echo "== serve repo (working tree) on 10.0.2.2:8000"
rm -rf /srv /tmp/w && mkdir /srv && cp -r /repo /tmp/w && rm -rf /tmp/w/.git
git -C /tmp/w init -q && git -C /tmp/w add -A && git -C /tmp/w -c user.name=t -c user.email=t@t commit -qm test
git clone -q --bare /tmp/w /srv/oracle.git && git -C /srv/oracle.git update-server-info
cp /repo/install.sh /repo/archinstall.json /srv/
python -m http.server -d /srv 8000 >/dev/null 2>&1 &

MODE=$MODE ISO=$ISO python -u - <<'PY'
import glob, os, re, select, socket, struct, subprocess, sys, time, zlib
PW = 'oracle-test-pw'
LUKS = r'(?i)passphrase for [^\r\n]*: '
MODE = os.environ['MODE']
log = open('/vm/serial.log', 'ab')

class VM:
    def __init__(s, extra):
        subprocess.run(['swtpm', 'socket', '--tpm2', '--tpmstate', 'dir=/vm/tpm', '--daemon',
                        '--ctrl', 'type=unixio,path=/vm/tpm.sock'], check=True)
        s.p = subprocess.Popen(['qemu-system-x86_64', '-machine', 'q35,accel=kvm', '-cpu', 'host', '-smp', '4', '-m', '6144',
            '-drive', 'if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd',
            '-drive', 'if=pflash,format=raw,file=/vm/vars.fd',
            '-drive', 'if=none,id=d0,file=/vm/disk.qcow2', '-device', 'nvme,drive=d0,serial=oracle',
            '-chardev', 'socket,id=tpm,path=/vm/tpm.sock', '-tpmdev', 'emulator,id=tpm0,chardev=tpm', '-device', 'tpm-crb,tpmdev=tpm0',
            '-nic', 'user,model=virtio-net-pci', '-device', 'virtio-vga', '-display', 'none',
            '-monitor', 'unix:/vm/mon.sock,server=on,wait=off', '-serial', 'stdio', *extra],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        s.buf = b''; s.all = b''; s.tick = None; s.t0 = time.time()

    def expect(s, pats, timeout, answers=(), fail=True):
        """wait for one of pats (regex); answer prompts in answers [(regex, text)] meanwhile. fail=False: -1 on timeout"""
        end = time.time() + timeout
        while True:
            for i, p in enumerate(pats):
                if m := re.search(p.encode(), s.buf):
                    s.buf = s.buf[m.end():]
                    return i, m
            for p, a in answers:
                if m := re.search(p.encode(), s.buf):
                    s.buf = s.buf[m.end():]
                    s.send(a + '\n')
            if time.time() > end:
                if not fail: return -1, None
                sys.exit(f'!! timeout waiting for {pats}\n--- serial tail ---\n{s.buf[-3000:].decode(errors="replace")}')
            if s.tick: s.tick()
            if select.select([s.p.stdout], [], [], 0.1 if s.tick else 1)[0]:
                d = os.read(s.p.stdout.fileno(), 65536)
                if not d:
                    sys.exit(f'!! qemu exited ({s.p.wait()}) waiting for {pats}\n--- serial tail ---\n{s.buf[-3000:].decode(errors="replace")}')
                log.write(d); log.flush()
                s.buf = s.buf[-400000:] + d; s.all += d

    def send(s, text):  # Enter = CR, like a real terminal
        time.sleep(0.5); s.p.stdin.write(text.replace('\n', '\r').encode()); s.p.stdin.flush()

    def sh(s, cmd, timeout=300, answers=(), show=60):
        s.buf = b''
        s.send(cmd + '; echo __RC=$?__\n')
        _, m = s.expect([r'__RC=(\d+)__'], timeout, answers)
        out = clean(s.prev(m))
        if show:
            print(f'$ {cmd}\n' + '\n'.join(out.splitlines()[-show:]) + f'\n[rc={m[1].decode()}]', flush=True)
        return int(m[1]), out

    def prev(s, m):
        return m.string[:m.start()].decode(errors='replace').split('__RC=$?__', 1)[-1]

    def mon(s, cmd):  # returns after the command finished (next prompt)
        c = socket.socket(socket.AF_UNIX); c.settimeout(20); c.connect('/vm/mon.sock'); b = b''
        while not b.endswith(b'(qemu) '): b += c.recv(4096)
        c.sendall(cmd.encode() + b'\n'); b = b''
        while not b.endswith(b'(qemu) '):
            d = c.recv(4096); b += d
            if not d: break  # quit: qemu closed the monitor
        c.close()

    def shot(s, name):
        """screendump → /vm/<name>.png; returns (lit pixels in the text band, its fingerprint, lit share of the screen).
        Text band = top 12% + left 6%: kernel/systemd text, prompts and the Limine menu header land there; a centred logo
        or the Oracle login does not"""
        s.mon(f'screendump /vm/{name}.ppm')
        d = open(f'/vm/{name}.ppm', 'rb').read(); os.remove(f'/vm/{name}.ppm')
        m = re.match(rb'P6\s+(\d+)\s+(\d+)\s+255\s', d); w, h, px = int(m[1]), int(m[2]), d[m.end():]
        ch = lambda t, b: struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b))
        raw = b''.join(b'\0' + px[y * w * 3:(y + 1) * w * 3] for y in range(h))
        open(f'/vm/{name}.png', 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
                                          + ch(b'IDAT', zlib.compress(raw, 6)) + ch(b'IEND', b''))
        lit = px.translate(LIT); edge = w * 3 * 6 // 100; top = h * 12 // 100
        band = lit[:top * w * 3] + b''.join(lit[y * w * 3:y * w * 3 + edge] for y in range(top, h))
        return band.count(1), zlib.crc32(band), round(lit.count(1) / len(lit), 4)

    def film(s, name, keys=None):
        """from now on: <name>-N.png about once a second; keys = monitor key sent every 0.15 s for the first 10 s"""
        s.frames = []; last = [0.0, 0.0]; s.fw = None; s.fw_seen = False  # fw = text band of the firmware screen (VM firmware prints, the G14 does not)
        def tick():
            t = time.time() - s.t0
            if keys and t < 10 and t - last[1] >= 0.15: s.mon('sendkey ' + keys); last[1] = t
            if t - last[0] >= 1:
                last[0] = t; n = len(s.frames) + 1; os_ = b'BdsDxe: starting' in s.all
                f = (n, round(t, 1), os_, *s.shot(f'{name}-{n}'))
                if not os_ or not s.fw_seen: s.fw = f[4]; s.fw_seen = os_
                s.frames.append(f)
        s.tick = tick

    def clean(s, f):  # frame shows nothing of ours: black, firmware logo, or firmware text left from before Limine
        return f[3] == 0 or f[4] == s.fw

    def keys(s, text):
        names = {'-': 'minus', '\n': 'ret', ' ': 'spc', '.': 'dot', '/': 'slash'}
        for ch in text:
            s.mon('sendkey ' + names.get(ch, ch)); time.sleep(0.05)

    def login(s, seen=False):
        seen or s.expect([r'oracle login:'], 300)
        s.send('son\n'); s.expect([r'Password:'], 60); s.send(PW + '\n')
        if s.expect([r'\$ $', '❯'], 60)[0]: s.send('exec bash\n'); s.expect([r'\$ $'], 60)  # zsh + starship → bash for the checks
        s.sh('set -o pipefail', show=0)

MENU_KEY = 'm'  # Space boots the selected entry in Limine's menu; letters it does not use only open it
LIT = bytes(int(i > 60) for i in range(256))
def clean(t): return re.sub(r'\x1b\[[0-9;:?]*[A-Za-z]|\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\r', '', t).strip()
def step(t): print(f'\n== {t}', flush=True)
ok = {}

if MODE != 'oracle':
    step(f'stage 1: boot {os.environ["ISO"]}, root shell on serial')
    opts = re.search(r'^options (.*)$', open(glob.glob('/vm/boot/loader/entries/01-*.conf')[0]).read(), re.M)[1]
    vm = VM(['-cdrom', os.environ['ISO'], '-kernel', '/vm/boot/arch/boot/x86_64/vmlinuz-linux',
             '-initrd', '/vm/boot/arch/boot/x86_64/initramfs-linux.img', '-append', f'{opts} console=ttyS0,115200'])
    vm.expect([r'archiso login:'], 600); vm.send('root\n'); time.sleep(3); vm.send('exec bash\n'); time.sleep(2)
    vm.sh('systemctl is-system-running --wait; uname -r', 300)
    if MODE == 'iso':
        rc, out = vm.sh('sleep 15; pgrep -af "oracle.install"; pkill -f "oracle.install"')
        ok['ISO autostarts the installer on tty1'] = 'install.sh' in out
    ENV = 'ORACLE_USER=son ORACLE_TZ=Asia/Ho_Chi_Minh ORACLE_KB=us ORACLE_RAW=http://10.0.2.2:8000 ORACLE_REPO=http://10.0.2.2:8000/oracle.git'
    RUN = f'{ENV} bash /root/oracle/install.sh' if MODE == 'iso' else f'curl -fsSL http://10.0.2.2:8000/install.sh | {ENV} bash'
    vm.buf = b''; vm.send(RUN + '\n')
    _, m = vm.expect([r'Type the disk to ERASE[^\r\n]*: '], 300)
    out = clean(m.string[:m.end()].decode(errors='replace')); print(out[out.find(':: Disks'):])
    ok['disk prompt lists nvme0n1, not the ISO'] = 'nvme0n1' in out and 'sr0' not in out
    vm.send('\x03'); vm.sh('true', show=0)
    vm.sh('mkdir -p /var/lib/iwd && printf "[Security]\\nPassphrase=oracle-wifi-pw\\n" >/var/lib/iwd/OracleTest.psk', show=0)
    step('stage 2: one pass, ORACLE_DISK=/dev/nvme0n1')
    vm.buf = b''; vm.send(RUN.replace('ORACLE_RAW', 'ORACLE_DISK=/dev/nvme0n1 ORACLE_RAW') + '\n')
    vm.expect([r'Password for son, root, disk: '], 300); vm.send(PW + '\n')
    vm.expect([r'Again: '], 30); vm.send(PW + '\n')
    i, m = vm.expect([r'press Enter to restart', r'\x1b\[31m!! [^\r\n]*'], 5400)
    out = clean(m.string[:m.end()].decode(errors='replace'))
    print('\n'.join(l for l in out.splitlines() if re.match(r'(::|!!|   \S|Installation completed|New TPM2|.*recovery key)', l))[-6000:])
    ok['one pass install (archinstall + Oracle + TPM)'] = i == 0 and 'RECOVERY KEY' in out and 'Oracle install failed' not in out
    if i: sys.exit('install failed')
    vm.send('\x03')
    vm.sh('ls /mnt/etc/sudoers.d; readlink /mnt/etc/resolv.conf; lsblk -o NAME,SIZE,FSTYPE /dev/nvme0n1')
    vm.sh('sed -i "/^ *cmdline:/s/$/ console=tty0 console=ttyS0,115200/" /mnt/boot/limine.conf && sed -i "/^KERNEL_CMDLINE/s/.$/ console=tty0 console=ttyS0,115200&/" /mnt/etc/default/limine'
          ' && grep -E "cmdline|^/|editor" /mnt/boot/limine.conf; cat /mnt/etc/default/limine; sync')
    vm.send('poweroff\n'); vm.p.wait(120)
    os.system('cd /vm && mv disk.qcow2 arch.qcow2 && qemu-img create -qf qcow2 -b arch.qcow2 -F qcow2 disk.qcow2'
              ' && cp vars.fd arch.vars.fd && cp -a tpm arch.tpm')

step('stage 3: first boot of the installed system, expect NO password prompt')
vm = VM([])
i, m = vm.expect([LUKS, r'oracle login:'], 600)
print('\n'.join(l for l in clean(m.string.decode(errors='replace')).splitlines()
                if re.search(r'Cryptography|passphrase|Encrypted Volumes|TPM', l)))
ok['first boot without password (TPM sealed from the ISO)'] = i == 1
if i == 0:
    vm.send(PW + '\n'); vm.expect([r'oracle login:'], 300)
vm.login(seen=True)
step('checks')
sudo = [(r'\[sudo\] password for son:', PW), (r'Disk password: ', PW)]
rc, out = vm.sh('ls /etc/sudoers.d; sudo -kn true')
ok['temporary NOPASSWD sudo removed'] = rc != 0 and 'oracle-install' not in out
vm.sh('sudo -v', 60, sudo, show=0)
rc, out = vm.sh('D=$(sudo cryptsetup status root | awk \'$1=="device:"{print $2}\'); sudo systemd-cryptenroll $D; lsblk -o NAME,SIZE /dev/nvme0n1;'
                ' cat /etc/mkinitcpio.conf.d/oracle-tpm.conf; sudo grep -v "^#" /etc/crypttab')
ok['TPM2 + recovery keyslots'] = re.search(r'\d+ recovery', out) and re.search(r'\d+ tpm2', out)
rc, out = vm.sh('systemctl is-active NetworkManager systemd-resolved; readlink /etc/resolv.conf')
ok['NetworkManager + resolved active, stub resolv.conf'] = out.count('active') == 2 and 'inactive' not in out and 'stub-resolv' in out
rc, _ = vm.sh('resolvectl query archlinux.org && curl -sSI https://archlinux.org | head -1')
ok['DNS'] = rc == 0
rc, out = vm.sh('nmcli -g NAME,TYPE connection show')
ok['Wi-Fi from the ISO → NetworkManager'] = 'OracleTest:802-11-wireless' in out
rc, _ = vm.sh('pacman -Q hyprland brave-origin-bin ghostty docker limine-snapper-sync waybar')
ok['packages'] = rc == 0
rc, out = vm.sh('Hyprland --verify-config --config ~/.config/hypr/hyprland.lua 2>&1 | tail -n 3')
ok['hyprland.lua verifies'] = rc == 0 and 'config ok' in out
rc, out = vm.sh('for i in $(seq 120); do docker ps --format "{{.Names}}" | grep -q dockge && break; sleep 5; done;'
                ' docker ps --format "{{.Names}} {{.Status}}"; systemctl is-enabled oracle-firstboot; journalctl -b -u oracle-firstboot -o cat | tail -n 8', 700)
ok['first boot unit started server apps, then disabled itself'] = 'dockge' in out and re.search(r'^disabled$', out, re.M)
INSTALL = 'curl -fsSL http://10.0.2.2:8000/install.sh | ORACLE_REPO=http://10.0.2.2:8000/oracle.git bash'
vm.sh('git -C ~/.local/share/oracle fetch -q http://10.0.2.2:8000/oracle.git && git -C ~/.local/share/oracle reset -q --hard FETCH_HEAD')  # served repo is new each run
rc, out = vm.sh(INSTALL, 1800, sudo, 6)
ok['install.sh re-run on the installed system (idempotent)'] = rc == 0 and 'already enrolled' in out
rc, _ = vm.sh('pacman -Q waybar fuzzel swaync hypridle swaybg fwupd fcitx5-bamboo loupe bluez micro nautilus noto-fonts')
ok['desktop packages'] = rc == 0
rc, out = vm.sh('Hyprland --verify-config --config ~/.config/hypr/hyprland.lua 2>&1 | tail -n 3')
ok['new hyprland config verifies'] = rc == 0 and 'config ok' in out
rc, out = vm.sh('sudo snapper -c root list | tail -n 2; sudo btrfs subvolume show /.snapshots >/dev/null && echo SNAPDIR', 60, sudo)
ok['snapshots set up'] = rc == 0 and 'SNAPDIR' in out
rc, out = vm.sh('sudo pacman -S --noconfirm cowsay >/dev/null; command -v cowsay; printf "1\\n" | oracle rollback; command -v cowsay || echo GONE', 600, sudo)
ok['oracle rollback takes back an update'] = 'GONE' in out and 'rolled back' in out
rc, out = vm.sh('sleep 10; sudo limine-update >/dev/null 2>&1; sudo grep -E "^ */|^[a-z_]+:|subvol" /boot/limine.conf | head -n 30; echo QUIET=$(sudo grep -c "cmdline:.*quiet loglevel=3" /boot/limine.conf);'
                ' efibootmgr | grep -i limine; bootctl is-installed 2>&1 | tail -n 1', 120, sudo)
ok['Limine boot menu: snapshots listed, editor off'] = 'editor_enabled: no' in out and 'Snapshots' in out and '.snapshots/' in out
ok['silent boot kept after snapshots + limine-update: menu hidden (quiet, timeout 1), quiet kernel line'] = (
    re.search(r'^quiet: yes$', out, re.M) and re.search(r'^timeout: 1$', out, re.M) and not re.search(r'^QUIET=0$', out, re.M))
rc, out = vm.sh('oracle set scale 1.25; oracle set keyboard de; oracle get scale; Hyprland --verify-config --config ~/.config/hypr/hyprland.lua 2>&1 | tail -n 2;'
                ' oracle set keyboard; oracle set scale; grep -c oracle/ghostty ~/.config/ghostty/config')
ok['settings file: Hyprland reads it, ghostty includes it'] = '1.25' in out and 'config ok' in out and re.search(r'^1$', out, re.M)
vm.sh('oracle set nightlight always; oracle set wallpaper $(ls /usr/share/hypr/*.png | head -1)')
step('tty1 login via monitor sendkey')
_, out = vm.sh('pgrep -a agetty | grep tty1')
if 'oracle-login' not in out: vm.keys('son\n'); time.sleep(2)  # Oracle login asks only for the password (user shown); old prompt asks the name first
vm.keys(PW + '\n'); time.sleep(25)
rc, out = vm.sh('pgrep -a cage; pgrep -af oracle-home; tmux list-windows -t oracle; loginctl list-sessions --no-legend')
ok['Shell mode + dashboard after tty1 login'] = rc == 0 and 'ghostty' in out and 'oracle-home' in out and 'home' in out
ok['workspaces 1-4'] = all(re.search(rf'^{i}: ', out, re.M) for i in (1, 2, 3, 4))
rc, out = vm.sh('pgrep -x wlsunset && pgrep -x swayidle && cat ~/.config/oracle/ghostty; pgrep -x fcitx5 || echo NO-IME')
ok['Shell mode: night light, idle dimming, ghostty settings file, no Vietnamese IME'] = 'font-size' in out and 'NO-IME' in out
rc, out = vm.sh('getent passwd son | cut -d: -f7; tmux display -p -t oracle:2 "#{pane_current_command}"; zsh -ic "type _pick_dir z; starship --version | head -n 1" 2>&1')
ok['zsh: login shell, in tmux, Ctrl+G picker, zoxide, starship'] = out.count('zsh') >= 2 and '_pick_dir is a shell function' in out and 'starship ' in out
rc, out = vm.sh('systemctl is-active oracle-lid; systemctl show -p Result --value oracle-battery; cat /etc/oracle/battery-limit')
ok['lid watcher running, battery unit ok'] = re.search(r'^active$', out, re.M) and 'success' in out
vm.mon('screendump /vm/shell.png -f png')
vm.sh('oracle gui; sleep 25')
rc, out = vm.sh('pgrep -a Hyprland; pgrep -x cage; cat ~/.local/state/oracle/mode')
ok['oracle gui → Hyprland'] = 'Hyprland' in out and 'cage' not in out.split('Hyprland')[-1]
vm.sh('export HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1); hyprctl dispatch \'hl.dsp.exec_cmd("ghostty")\'; sleep 8; hyprctl clients | grep -c "class: com.mitchellh.ghostty"')
rc, out = vm.sh('pgrep -x waybar && pgrep -x swaync && pgrep -x hypridle && pgrep -x fcitx5 && fc-list | wc -l')
ok['desktop: waybar, notifications, idle, Vietnamese IME running, fonts installed'] = rc == 0 and int(out.split()[-1]) > 20
rc, out = vm.sh('sleep 5; pgrep -x wlsunset; pgrep -a swaybg; oracle set nightlight; oracle set wallpaper')
ok['desktop start: night light on, wallpaper applied'] = re.search(r'^\d+$', out, re.M) and 'swaybg -i' in out
vm.mon('screendump /vm/gui.png -f png')
vm.sh('HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1) oracle shell; sleep 20')
rc, out = vm.sh('export HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1); hyprctl clients | grep -c "class: oracle.shell"; hyprctl monitors | grep "special workspace"; hyprctl configerrors; tmux ls')
ok['oracle shell → Shell over the desktop (Hyprland stays), tmux kept'] = 'special:shell' in out and 'oracle' in out.split('special:shell')[-1] and re.search(r'^1$', out, re.M)

def frames(vm):
    for f in vm.frames: print(f'  {f[0]:>3} t={f[1]:>5}s {"loader/os" if f[2] else "firmware "} text-band={f[3]:<6} lit={f[5]:<7} {"" if vm.clean(f) else "TEXT"}')
    return [f for f in vm.frames if f[2]]
step('boot: power on, no key pressed (unattended), screenshot ~1/s → boot-N.png')
vm.send('sudo poweroff\n'); vm.p.wait(120)
vm = VM([]); vm.film('boot')
i, _ = vm.expect([LUKS, r'oracle login:'], 300)
t_login = round(time.time() - vm.t0, 1)
vm.expect([r'(?!)'], 5, fail=False); vm.tick = None
own = frames(vm); band, _, lit = vm.shot('boot-login')
print(f'serial login prompt after {t_login}s from power-on; boot-login: text-band={band} lit={lit}')
ok['unattended boot: no password, no boot menu, no text on screen'] = i == 1 and own and all(vm.clean(f) for f in own[1:])
ok['styled login on tty1 (centred, nothing in the text band)'] = band == 0 and lit > 0.002
FW = vm.fw  # firmware screen as Limine finds it (same every boot)
vm.login(seen=True); vm.sh('sudo -v', 60, sudo, show=0)
vm.sh('systemctl is-system-running --wait; systemd-analyze; systemd-analyze blame | head -n 10; cat /proc/cmdline', 300)
rc, out = vm.sh('for i in $(seq 60); do docker ps --format "{{.Names}}" | grep -q dockge && break; sleep 5; done; docker ps --format "{{.Names}}";'
                ' echo FAILED=$(systemctl --failed --no-legend | wc -l); systemctl is-active getty@tty1; pgrep -a agetty; sudo stty -F /dev/tty1 -a | grep -oE "(-)?(cs8|istrip|iutf8)";'
                ' sudo head -n 8 /boot/limine.conf; sudo grep -c "cmdline:.*quiet" /boot/limine.conf;'
                ' oracle doctor | grep -iE "boot|login|services"', 400)
ok['after a plain power-on: server apps up, nothing failed, tty1 login running'] = 'dockge' in out and 'FAILED=0' in out and re.search(r'^active$', out, re.M)
step(f'boot menu: {MENU_KEY} tapped from power-on → boot-menu-top.png, then Snapshots opened → boot-menu.png')
vm.send('sudo poweroff\n'); vm.p.wait(120)
vm = VM([]); vm.film('menu', keys=MENU_KEY)
i, _ = vm.expect([r'oracle login:'], 40, fail=False); vm.tick = None
frames(vm)
f = (0, 0, True, *vm.shot('boot-menu-top'))
for k in ('down', 'ret'): vm.mon('sendkey ' + k); time.sleep(0.5)
time.sleep(1); vm.shot('boot-menu')
ok['key at power-on opens the boot menu (and it waits)'] = i == -1 and f[3] > 0 and f[4] != FW
vm.mon('quit'); vm.p.wait(60)
step('TPM cannot unlock (blank TPM) → password prompt → boot-tpm-fail.png, typed on the screen keyboard')
os.system('while pgrep -x swtpm >/dev/null; do sleep 0.5; done; rm -rf /vm/tpm && mkdir /vm/tpm')
vm = VM([]); vm.film('tpm')
i = -1
for _ in range(60):  # until the screen shows something of ours for 2 frames (the prompt), max ~2 min
    i, _ = vm.expect([LUKS], 2, fail=False)
    if i == 0 or len(vm.frames) > 3 and not any(vm.clean(f) for f in vm.frames[-2:]): break
vm.expect([r'(?!)'], 3, fail=False)
band, _, lit = vm.shot('boot-tpm-fail')
print(f'prompt on serial too: {i == 0}; boot-tpm-fail: text-band={band} lit={lit}')
vm.keys(PW + '\n')
j, _ = vm.expect([r'oracle login:'], 240, fail=False); vm.tick = None
frames(vm); band2, _, lit2 = vm.shot('boot-tpm-after')
print(f'after typing the password: serial login {j == 0}; screen text-band={band2} lit={lit2}')
ok['TPM fails: password prompt readable on screen, keyboard unlocks, boots to login'] = band > 0 and band != FW and j == 0
vm.mon('system_powerdown'); vm.p.wait(120)
step('result')
for k, v in ok.items():
    print(('PASS ' if v else 'FAIL ') + k)
sys.exit(0 if all(ok.values()) else 1)
PY
