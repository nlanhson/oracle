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

    def off(s):  # a slow poweroff must not hide the results
        s.send('sudo poweroff\n'); t = time.time()
        try:  # the sudo ticket is gone after 15 quiet minutes: answer the prompt, or poweroff never runs
            if s.expect([r'\[sudo\] password for son:'], 4, fail=False)[0] == 0: s.send(PW + '\n')
        except SystemExit: pass  # qemu already gone
        try: s.p.wait(180)
        except subprocess.TimeoutExpired: s.p.kill(); s.p.wait(30); os.system('pkill -x swtpm')
        s.off_s = round(time.time() - t, 1)
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
        names = {'-': 'minus', '\n': 'ret', ' ': 'spc', '.': 'dot', '/': 'slash', '*': 'asterisk'}
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
rc, _ = vm.sh('pacman -Q waybar python-gobject gtk4-layer-shell fd swaync hypridle swaybg fwupd fcitx5-bamboo loupe bluez micro nautilus noto-fonts')
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
step('tty1 login via monitor sendkey (fresh state: welcome guide first)')
vm.sh('rm -f ~/.local/state/oracle/done/welcome; ls ~/.local/state/oracle/migrations | grep -c .')
rc, _ = vm.sh('ps -t tty1 -o comm= | grep -x agetty')  # old prompt: agetty asks the name; Oracle login: login already waits for son's password
if rc == 0: vm.keys('son\n'); time.sleep(2)
vm.keys(PW + '\n'); time.sleep(25)
rc, out = vm.sh('pgrep -a cage; pgrep -f oracle-welcome >/dev/null && echo WELCOME-RUNNING; tmux capture-pane -p -t oracle:1 | grep "welcome .* 1 of"; ls ~/.local/state/oracle/done')
ok['fresh install: first Shell-mode start shows the welcome guide'] = rc == 0 and 'ghostty' in out and 'WELCOME-RUNNING' in out and re.search(r'welcome . 1 of', out)
vm.sh('tmux send-keys -t oracle:1 Escape; sleep 4')
rc, out = vm.sh('pgrep -f oracle-welcome >/dev/null && echo WELCOME-RUNNING || echo NO-WELCOME; pgrep -af oracle-home; ls ~/.local/state/oracle/done')
ok['Esc skips it: dashboard comes up, marked done'] = 'NO-WELCOME' in out and 'oracle-home' in out and re.search(r'^welcome$', out, re.M)
vm.sh('tmux kill-window -t oracle:1; sleep 5')
rc, out = vm.sh('pgrep -f oracle-welcome >/dev/null && echo WELCOME-RUNNING || echo NO-WELCOME; pgrep -af oracle-home; tmux list-windows -t oracle')
ok['second start goes straight to the dashboard'] = 'NO-WELCOME' in out and 'oracle-home' in out
vm.sh('rm ~/.local/state/oracle/done/welcome; bash ~/.local/share/oracle/migrations/1793900000.sh; ls ~/.local/state/oracle/done; tmux kill-window -t oracle:1; sleep 5')
rc, out = vm.sh('pgrep -f oracle-welcome >/dev/null && echo WELCOME-RUNNING || echo NO-WELCOME; pgrep -af oracle-home; tmux list-windows -t oracle')
ok['existing install (after the update migration): no welcome, dashboard'] = 'NO-WELCOME' in out and 'oracle-home' in out
rc, out = vm.sh('pgrep -a cage; tmux list-windows -t oracle; loginctl list-sessions --no-legend')
ok['Shell mode + dashboard after tty1 login'] = rc == 0 and 'ghostty' in out and 'home' in out
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
rc, out = vm.sh('pacman -Q satty hyprshot wl-clipboard')
ok['screenshot packages (satty editor)'] = rc == 0
rc, out = vm.sh('export HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1); export WAYLAND_DISPLAY=$(cd $XDG_RUNTIME_DIR; ls wayland-[0-9] | tail -1); rm -rf ~/Pictures/Screenshots; swaync-client -C; oracle shot screen; sleep 3; ls ~/Pictures/Screenshots; wl-paste -l; echo COUNT=$(swaync-client -c)')
ok['oracle shot screen: PNG saved, image on the clipboard, notification up'] = re.search(r'Screenshot .*\.png', out) and 'image/png' in out and re.search(r'COUNT=[1-9]', out)
vm.mon('screendump /vm/shot-notification.png -f png')
rc, out = vm.sh('export HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1); gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.GetCapabilities; grep -c "oracle shot" ~/.local/share/oracle/default/hypr/modules/binds.lua; oracle shot bogus; echo rc=$?')
ok['Print / Shift+Print / Super+Print bound to oracle shot; actions supported'] = 'actions' in out and re.search(r'^3$', out, re.M) and 'rc=1' in out
step('one look: every surface on a white wallpaper')
import base64, struct, zlib
def png(w, h):  # plain white picture, made here (the VM has no image tools)
    ch = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d))
    return b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + ch(b'IDAT', zlib.compress((b'\0' + b'\xff' * 3 * w) * h)) + ch(b'IEND', b'')
rc, out = vm.sh('bash ~/.local/share/oracle/test/look.sh', 120)
ok['look: tokens → generated files, one edit changes all, migration swaps old copies only'] = rc == 0 and 'look ok' in out
vm.sh(f'echo {base64.b64encode(png(1280, 800)).decode()} | base64 -d >/tmp/white.png; oracle set wallpaper /tmp/white.png', show=0)
VMENV = ('export XDG_RUNTIME_DIR=/run/user/$(id -u) HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1)'
         ' WAYLAND_DISPLAY=$(cd $XDG_RUNTIME_DIR && ls -d wayland-? | head -1)')
vm.sh(VMENV + '; bash ~/.local/share/oracle/migrations/1794366900.sh; oracle look; hyprctl reload; pkill -x waybar; pkill -x swaync; pkill -x swayosd-server;'  # = what oracle update does
      ' for c in waybar swaync swayosd-server; do setsid -f $c &>/dev/null; done; oracle wall; setsid -f ghostty --class=oracle.manual'
      ' --gtk-single-instance=false --window-width=70 --window-height=18 -e oracle manual &>/dev/null; sleep 8', 60, show=0)
vm.mon('screendump /vm/look-desktop.png -f png')
rc, out = vm.sh('fc-match sans-serif; fc-match system-ui; fc-match monospace; fc-list | grep -ci "/inter" ; xdg-user-dir >/dev/null; gsettings get org.gnome.desktop.interface font-name')
ok['look: Inter installed, sans-serif and system-ui resolve to it, monospace is not Inter'] = out.count('Inter.ttc') == 2 and "'Inter 11'" in out and 'Inter' not in out.splitlines()[2]
vm.sh('pkill -fx ghostty; sleep 2', 30, show=0)
vm.mon('screendump /vm/look-desktop-float.png -f png')
rc, out = vm.sh('hyprctl configerrors; hyprctl getoption decoration:rounding | head -n 1; hyprctl getoption general:col.active_border | head -n 1;'
                ' hyprctl layers | grep -E "namespace" | sort -u')
ok['look: Hyprland config has no errors, rounding from tokens, bar layer present'] = 'int: 8' in out and 'waybar' in out
step('launcher')
LENV = VMENV + '; export ORACLE_LAUNCHER_TIMING=1'
def lshot(text, name, wait=1.5):  # open the launcher, type, picture, Esc
    vm.sh(LENV + '; oracle launcher; sleep 1.5', 30, show=0); vm.keys(text); time.sleep(wait)
    vm.mon(f'screendump /vm/{name}.png -f png'); vm.mon('sendkey esc'); time.sleep(1)
vm.sh('pkill -f oracle.manual; mkdir -p ~/Documents; touch ~/Documents/Quarterly-report-2026.pdf', 30, show=0)
rc, out = vm.sh(LENV + '; pkill -f oracle-launcher; sleep 1; rm -f $XDG_RUNTIME_DIR/oracle-launcher.timing; setsid -f oracle launcher daemon &>/dev/null; sleep 5; pgrep -fc "python3.*oracle-launcher"')
ok['launcher: daemon starts at login (one process)'] = rc == 0 and out.split()[-1] == '1'
lshot('gho', 'launcher-white')  # white wallpaper: contrast
rc, out = vm.sh(LENV + '; oracle launcher; sleep 1.5; hyprctl layers | grep -c "namespace: launcher"; oracle launcher; sleep 1; hyprctl layers | grep -c "namespace: launcher"')
ok['launcher: layer namespace is "launcher" (blur + no_anim rules match), closes on the key'] = out.split()[-2:] == ['1', '0'] and "^launcher$" in open('/repo/default/hypr/modules/decorations.lua').read()
vm.sh(LENV + '; oracle set wallpaper ~/.local/share/oracle/default/wallpapers/dunes.jpg; oracle wall; sleep 4', 30, show=0)
lshot('', 'launcher-empty')
lshot('gho', 'launcher-apps'); lshot('upd', 'launcher-oracle'); lshot('12*7', 'launcher-sum'); lshot('quarterly', 'launcher-files')
vm.sh(LENV + '; oracle launcher power; sleep 1.5', 30, show=0); time.sleep(1); vm.mon('screendump /vm/launcher-power.png -f png'); vm.mon('sendkey esc'); time.sleep(1)
rc, out = vm.sh('python3 ~/.local/share/oracle/bin/oracle-launcher --power --query ""')
ok['launcher: power menu lists its 4 entries'] = [l.split('\t')[1] for l in out.splitlines() if l.startswith('power')] == ['Lock', 'Sleep', 'Restart', 'Shut Down']
vm.sh(LENV + '; oracle launcher; sleep 1.5', 30, show=0); vm.keys('mousepad\n'); time.sleep(15)
rc, out = vm.sh(VMENV + '; echo W$(hyprctl clients | grep -ci "class: .*mousepad") P$(pgrep -fc "[m]ousepad"); pkill -f mousepad; true')
ok['launcher: Enter on an app starts it (mousepad process runs)'] = bool(re.search(r'P[1-9]', out))
vm.sh(LENV + '; oracle launcher; sleep 1.5', 30, show=0); vm.keys('12*7\n'); time.sleep(2)
rc, out = vm.sh(VMENV + '; wl-paste')
ok['launcher: Enter on a sum copies the result'] = '84' in out
vm.mon('sendkey meta_l-spc'); time.sleep(2)
rc, out = vm.sh(VMENV + '; hyprctl layers | grep -c "namespace: launcher"')
ok['launcher: Super+Space (the real key) opens it'] = out.split()[-1] == '1'
vm.mon('sendkey meta_l-spc'); time.sleep(1)
vm.sh(LENV + '; for i in 1 2 3 4 5 6; do oracle launcher; sleep 1; oracle launcher; sleep 1; done; sort -n $XDG_RUNTIME_DIR/oracle-launcher.timing | tr "\\n" " "')
rc, out = vm.sh('sort -n $XDG_RUNTIME_DIR/oracle-launcher.timing | awk \'{a[NR]=$1} END{print NR, "median", a[int((NR+1)/2)]}\'', 30)
ok['launcher: time to first picture under 150 ms (median, software rendering)'] = re.search(r'median [\d.]+', out) is not None and float(out.split()[-1]) < 150
rc, out = vm.sh('bash ~/.local/share/oracle/test/launcher.sh | tail -n 30', 120)
ok['launcher: 20+ scripted queries, expected top row (test/launcher.sh)'] = rc == 0 and 'launcher ok' in out
rc, out = vm.sh('for q in gho upd shut "12*7" quarterly; do python3 ~/.local/share/oracle/bin/oracle-launcher --query "$q" | head -n 1; done')
ok['launcher: real apps, ranked top rows'] = re.search(r'app\tGhostty', out) and re.search(r'cmd\toracle update', out) and re.search(r'power\tShut Down', out) and 'sum\t84' in out and 'Quarterly-report-2026.pdf' in out
LB = 'python3 ~/.local/share/oracle/bin/oracle-launcher'
vm.sh(LENV + '; oracle launcher; sleep 1.5', 30, show=0); vm.keys('shut'); time.sleep(1); vm.mon('sendkey ret'); time.sleep(1.5)
vm.mon('screendump /vm/launcher-confirm.png -f png'); vm.mon('sendkey ret'); time.sleep(1.5)
rc, out = vm.sh('echo alive; ' + VMENV + '; hyprctl layers | grep -c "namespace: launcher"; pgrep -c Hyprland')
ok['launcher: Shut Down asks first (Cancel is the default, machine still up after Enter)'] = 'alive' in out and out.split()[-2:] == ['1', '1']
vm.mon('sendkey esc'); time.sleep(1)
rc, out = vm.sh(f'for l in b c d f g l m n p s v h; do {LB} --query $l | head -n 2 | cut -f1 | paste -sd, | grep -qx app,app && {{ echo LEARN $l; {LB} --query $l | sed -n 2p | cut -f2; break; }}; done')
m = re.search(r'LEARN (\w)\n(.+)', out)
if m:
    for _ in range(3):
        vm.sh(LENV + '; oracle launcher; sleep 1.5', 30, show=0); vm.keys(m[1]); time.sleep(1); vm.mon('sendkey down'); time.sleep(0.5); vm.mon('sendkey ret'); time.sleep(5)
        vm.sh(VMENV + '; for w in $(hyprctl clients -j | jq -r ".[].pid"); do kill $w; done; sleep 2', 30, show=0)
    rc, out2 = vm.sh(f'{LB} --query {m[1]} | head -n 1 | cut -f2')
    ok['launcher: it learns (3 picks of the 2nd app after one letter make it the top hit)'] = out2.splitlines()[0].strip() == m[2].strip()
else:
    ok['launcher: it learns (3 picks of the 2nd app after one letter make it the top hit)'] = False
vm.sh(VMENV + '; oracle set wallpaper /tmp/white.png; oracle wall; sleep 3', 30, show=0)
vm.sh('for i in 1 2; do notify-send "Test notification $i" "Tiếng Việt: Xin chào, đã lưu ảnh. 4,243 photos synced, this line is longer to see wrapping."; done; sleep 3', 30, show=0)
vm.mon('screendump /vm/look-notify.png -f png')
vm.sh('swaync-client -t; sleep 3', 30, show=0)
vm.mon('screendump /vm/look-panel.png -f png')
vm.sh('swaync-client -cp; swaync-client -C; sleep 1', 30, show=0)
vm.sh(VMENV + '; swayosd-client --output-volume 0; sleep 0.7', 30)
vm.mon('screendump /vm/look-osd.png -f png')
vm.sh('sleep 3; setsid -f hyprlock &>/dev/null; sleep 6', 30, show=0)
vm.mon('screendump /vm/look-lock.png -f png')
rc, out = vm.sh('pgrep -x hyprlock; pkill -USR1 hyprlock; sleep 3; pgrep -x hyprlock || echo UNLOCKED')
ok['look: lock screen shows, unlocks on signal'] = 'UNLOCKED' in out
step('control panel and notifications')
rc, out = vm.sh('bash ~/.local/share/oracle/test/panel.sh', 120)
ok['panel: config valid, helpers change state (fakes), migration swaps untouched copies'] = rc == 0 and 'panel ok' in out
vm.sh(VMENV + '; bash ~/.local/share/oracle/migrations/1794453300.sh; pkill -x waybar; pkill -x swaync; for c in swaync waybar; do setsid -f $c &>/dev/null; done; sleep 6', 60, show=0)
rc, out = vm.sh(VMENV + '; grep -q "\\"notifications\\"" ~/.config/swaync/config.json && ! grep -q slider ~/.config/swaync/config.json && echo CFG-NEW; pgrep -x swaync && pgrep -x waybar && echo RUNNING; hyprctl configerrors')
ok['panel: Notification Center config (cards only) installed by the migration, swaync runs with it'] = all(x in out for x in ("CFG-NEW", "RUNNING"))
rc, out = vm.sh(VMENV + '; oracle panel dnd true; oracle panel dnd; swaync-client -D; oracle panel dnd false; swaync-client -D')
ok['panel: Do Not Disturb tile really switches swaync'] = re.search(r'true\s*true\s*false', out) is not None
rc, out = vm.sh(VMENV + '; oracle panel night true; sleep 1; pgrep -x wlsunset; oracle get nightlight; oracle panel night false; sleep 1; pgrep -x wlsunset || echo NO-WLSUNSET; oracle panel night')
ok['panel: night light tile starts and stops wlsunset'] = re.search(r'^\d+$', out, re.M) and 'always' in out and 'NO-WLSUNSET' in out
rc, out = vm.sh(VMENV + '; wpctl status | head -n 14; wpctl get-volume @DEFAULT_AUDIO_SINK@; oracle panel mute true; wpctl get-volume @DEFAULT_AUDIO_SINK@; oracle panel mute; oracle panel mute false; oracle panel mute')
if 'MUTED' in out:  # a sound card exists in the VM
    ok['panel: mute tile changes the real volume state (wpctl)'] = out.count('MUTED') >= 1 and 'true' in out and 'false' in out
else:
    print('NOTE: no audio output in the VM, mute/volume not exercised here (panel.sh covers the command logic with fakes)')
rc, out = vm.sh('ls /sys/class/backlight | head -n 1; echo rc=$?; oracle panel charge; cat /etc/oracle/battery-limit')
print('NOTE: brightness cannot be tested in the VM unless a backlight exists (above)')
vm.sh(VMENV + '; swaync-client -t -sw; sleep 2', 30, show=0)
vm.mon('screendump /vm/nc-open-white.png -f png')  # white wallpaper
vm.sh(VMENV + '; swaync-client -cp -sw; oracle set wallpaper ~/.local/share/oracle/default/wallpapers/dunes.jpg; oracle wall; sleep 3; swaync-client -op -sw; sleep 2', 30, show=0)
vm.mon('screendump /vm/nc-open-dunes.png -f png')
vm.sh(VMENV + '; swaync-client -cp -sw; sleep 1; swaync-client -C; notify-send -a Messages "Anh Minh" "Tối nay đi ăn phở không? Mình đặt bàn lúc 7 giờ nhé."; notify-send -a Messages "Anh Minh" "Địa chỉ: 12 Lý Tự Trọng"; notify-send -a Immich "Backup finished" "4,243 photos synced."; notify-send -u critical -a Updates "Disk almost full" "Only 2 GB left on /."; sleep 2', 30, show=0)
vm.mon('screendump /vm/nc-banner.png -f png')
rc, out = vm.sh(VMENV + '; swaync-client -c; hyprctl layers | grep -c swaync-notification-window; sleep 7; swaync-client -op -sw; sleep 2')
ok['panel: banners appear under the bar, 4 unread counted'] = ''.join(out.split()).startswith('41')
vm.mon('screendump /vm/nc-open.png -f png')  # 3 notifications, 2 apps
vm.sh(VMENV + '; swaync-client -cp -sw; swaync-client -C; sleep 1; oracle panel dnd true; notify-send -a Messages "Silent" "DND on: no banner"; sleep 2', 30, show=0)
vm.mon('screendump /vm/panel-dnd.png -f png')  # bar shows the DND bell + dot, no banner
rc, out = vm.sh(VMENV + '; swaync-client -c; hyprctl layers | grep -c swaync-notification-window')
ok['panel: Do Not Disturb keeps the notification in the list but shows no new banner'] = ''.join(out.split()).startswith('10')
vm.sh(VMENV + '; swaync-client -op -sw; sleep 2', 30, show=0)
vm.mon('screendump /vm/panel-dnd-open.png -f png')
vm.sh(VMENV + '; swaync-client -cp -sw; swaync-client -C; sleep 1; notify-send -u critical -a Updates "Disk almost full" "Critical goes through"; sleep 2', 30, show=0)
rc, out = vm.sh(VMENV + '; hyprctl layers | grep -c swaync-notification-window')
ok['panel: Do Not Disturb still lets a critical notification through'] = ''.join(out.split()).startswith('1')
vm.mon('screendump /vm/panel-dnd-critical.png -f png')
vm.sh(VMENV + '; oracle panel dnd false; swaync-client -C; sleep 1; swaync-client -Ia test-quiet; notify-send "Quiet" "inhibited: no banner"; sleep 2', 30, show=0)
rc, out = vm.sh(VMENV + '; swaync-client -c; hyprctl layers | grep -c swaync-notification-window')
ok['panel: inhibitor on → no banner, notification still counted'] = ''.join(out.split()).startswith('10')
vm.sh(VMENV + '; swaync-client -Ir test-quiet; swaync-client -C; sleep 1; notify-send "Loud" "inhibitor off: banner"; sleep 2', 30, show=0)
rc, out = vm.sh(VMENV + '; swaync-client -c; hyprctl layers | grep -c swaync-notification-window')
ok['panel: inhibitor off → banner shows again'] = ''.join(out.split()).startswith('11')
vm.sh(VMENV + '; swaync-client -C; sleep 6; (setsid -f oracle panel quiet &>/dev/null); setsid -f hyprlock &>/dev/null; sleep 9; notify-send "Locked" "no banner while locked"; sleep 2', 40, show=0)
rc, out = vm.sh(VMENV + '; swaync-client -c; hyprctl layers | grep -c swaync-notification-window')
ok['panel: no banner while the lock screen is showing (watcher), still collected'] = ''.join(out.split()).startswith('10')
vm.sh(VMENV + '; pkill -USR1 hyprlock; sleep 8; swaync-client -C; sleep 1; notify-send "Unlocked" "banner is back"; sleep 2', 40, show=0)
rc, out = vm.sh(VMENV + '; hyprctl layers | grep -c swaync-notification-window; pkill -f "oracle panel quiet"')
ok['panel: banners return after unlock'] = ''.join(out.split()).startswith('1')
vm.sh(VMENV + '; oracle panel dnd false; swaync-client -C; swaync-client -cp -sw; sleep 1', 30, show=0)
rc, out = vm.sh(VMENV + '; hyprctl dispatch "hl.dsp.exec_cmd(\\"oracle panel settings network\\")" >/dev/null; sleep 6; hyprctl clients | grep -E "class: oracle.settings|floating: 1" | head -n 4; hyprctl configerrors')
ok['panel: Settings button opens a floating oracle.settings pop-up'] = 'oracle.settings' in out
vm.mon('screendump /vm/panel-settings.png -f png')
vm.sh('pkill -f oracle.settings; sleep 1', 30, show=0)
step('Control Center (Quickshell)')
vm.sh(VMENV + '; pgrep -x "qs|quickshell" >/dev/null || setsid -f qs -p ~/.local/share/oracle/default/quickshell &>/dev/null; sleep 6; oracle panel dnd false; oracle panel night false', 40, show=0)
rc, out = vm.sh(VMENV + '; pgrep -x "qs|quickshell" | head -n 1; oracle panel; sleep 2; hyprctl layers | grep -c "namespace: oracle-panel"; oracle panel; sleep 1; hyprctl layers | grep -c "namespace: oracle-panel"; hyprctl configerrors')
ok['control center: `oracle panel` opens a layer "oracle-panel", a second call closes it, no Hyprland config errors'] = re.search(r'^1\s*$', out, re.M) is not None and re.search(r'^0\s*$', out, re.M) is not None and 'error' not in out.lower()
vm.sh(VMENV + '; pkill -x swaybg; setsid -f swaybg -c ffffff &>/dev/null; oracle panel; sleep 2', 30, show=0)
vm.mon('screendump /vm/cc-open-white.png -f png')
vm.sh(VMENV + '; oracle panel; oracle wall; sleep 2; oracle panel; sleep 2', 30, show=0)
vm.mon('screendump /vm/cc-open.png -f png')  # dunes
vm.sh(VMENV + '; oracle panel dnd true; oracle panel night true; sleep 3', 30, show=0)
vm.mon('screendump /vm/cc-states.png -f png')  # DND and night light on (the panel polls while open)
vm.sh(VMENV + '; oracle panel; oracle panel dnd false; oracle panel night false; oracle set accent cyan; oracle look; sleep 2; oracle panel; sleep 3', 40, show=0)
vm.mon('screendump /vm/cc-cyan.png -f png')
vm.sh(VMENV + '; oracle panel; oracle set accent; oracle look; sleep 1', 30, show=0)
rc, out = vm.sh('sudo pacman -S --noconfirm --needed wtype >/dev/null 2>&1; ' + VMENV + '; oracle panel; sleep 2; hyprctl layers | grep -c "namespace: oracle-panel"; wtype -k Escape; sleep 1.5; hyprctl layers | grep -c "namespace: oracle-panel"; which wtype', 300, sudo)
ok['control center: Esc closes it'] = bool(re.search(r'^1\s*\n0\s*\n', out, re.M))
vm.sh(VMENV + '; oracle panel close; sleep 1', 30, show=0)
rc, out = vm.sh(VMENV + '; P=$(pgrep -x "qs|quickshell" | head -n 1); t() { awk "{print \\$14+\\$15}" /proc/$P/stat; }; a=$(t); sleep 30; b=$(t); echo CPUTICKS=$((b-a)) of $(getconf CLK_TCK)/s over 30s; grep VmRSS /proc/$P/status; pgrep -x "qs|quickshell" >/dev/null && echo ALIVE', 90)
print(out)
ok['control center: quickshell survives 30 s idle (see CPU/RSS above)'] = 'ALIVE' in out
rc, out = vm.sh(VMENV + '; swaync-client -t -sw; sleep 2; hyprctl layers | grep -c "namespace: swaync-control-center"; swaync-client -cp -sw')
ok['notification center: the date click command opens swaync'] = 'swaync-control-center' in out or re.search(r'^1\s*$', out, re.M) is not None
rc, out = vm.sh(VMENV + '; notify-send -a Messages "Dot" "unread"; sleep 2; timeout 3 swaync-client -swb; hyprctl configerrors')
ok['bar: unread dot state still reported by swaync (custom/panel)'] = 'notification' in out
vm.sh('setsid -f nautilus &>/dev/null; sleep 10', 30, show=0)
vm.mon('screendump /vm/look-gtk.png -f png')
vm.sh(VMENV + '; oracle set wallpaper ~/.local/share/oracle/default/wallpapers/dunes.jpg; oracle wall; sleep 4', 30, show=0)
vm.mon('screendump /vm/look-app.png -f png')  # bar with an app in use
vm.sh('pkill -x nautilus; sleep 3', 30, show=0)
vm.mon('screendump /vm/look-idle.png -f png')  # empty desktop: bar + Oracle's own wallpaper
vm.sh('HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1) oracle shell; sleep 20')
rc, out = vm.sh('export HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1); hyprctl clients | grep -c "class: oracle.shell"; hyprctl monitors | grep "special workspace"; hyprctl configerrors; tmux ls')
ok['oracle shell → Shell over the desktop (Hyprland stays), tmux kept'] = 'special:shell' in out and 'oracle' in out.split('special:shell')[-1] and re.search(r'^1$', out, re.M)

def frames(vm):
    for f in vm.frames: print(f'  {f[0]:>3} t={f[1]:>5}s {"loader/os" if f[2] else "firmware "} text-band={f[3]:<6} lit={f[5]:<7} {"" if vm.clean(f) else "TEXT"}')
    return [f for f in vm.frames if f[2]]
step('boot: power on, no key pressed (unattended), screenshot ~1/s → boot-N.png')
vm.off()
print(f'poweroff from the desktop took {vm.off_s}s')
ok['shutdown from the desktop takes under 30 s'] = vm.off_s < 30
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
                ' oracle doctor | grep -iE "boot|login|services"; for u in $(systemctl --failed --plain --no-legend | cut -d" " -f1); do journalctl -b -u "$u" -o short-monotonic | tail -n 6; done', 400)
ok['after a plain power-on: server apps up, nothing failed, tty1 login running'] = 'dockge' in out and 'FAILED=0' in out and re.search(r'^active$', out, re.M)
step('Oracle login on tty1: a wrong password, then the right one → boot-login-wrong.png')
screen = lambda: vm.sh('sudo cat /dev/vcs1 | tr -s " " | fold -w 160', show=0)[1]
print('tty1 shows:', screen()[-160:])
vm.keys('wrong-pw\n'); time.sleep(8); vm.shot('boot-login-wrong'); t = screen(); print('after a wrong password:', t[-200:])
if re.search(r'login: *$', t): vm.keys('son\n'); time.sleep(2)
vm.keys(PW + '\n'); time.sleep(20)
rc, out = vm.sh('pgrep -a cage; loginctl list-sessions --no-legend')
ok['Oracle login: wrong password refused, right password starts Shell mode'] = 'incorrect' in t and 'cage' in out and 'tty1' in out
step(f'boot menu: {MENU_KEY} tapped from power-on → boot-menu-top.png, then Snapshots opened → boot-menu.png')
vm.off()
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
