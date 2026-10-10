#!/usr/bin/env bash
# VM test, needs only docker + /dev/kvm. Arch ISO → install.sh (archinstall.json) → reboot, LUKS password → install.sh (Oracle + TPM)
# → reboot with no password → checks. Disk = NVMe of G14 size (sparse). Files in $VM_DIR. Log: $VM_DIR/serial.log.
# test/vm.sh          full run (~15-20 min)
# test/vm.sh oracle   reuse installed Arch from last full run
set -euo pipefail
if [[ ! -f /.dockerenv ]]; then
  ROOT=$(cd "$(dirname "$0")/.." && pwd)
  VM=${VM_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oracle-vm}
  mkdir -p "$VM"
  exec docker run --rm -i --device /dev/kvm -e OWNER="$(id -u):$(id -g)" -v "$ROOT:/repo:ro" -v "$VM:/vm" archlinux:latest bash /repo/test/vm.sh "$@"
fi
trap 'chown -R "$OWNER" /vm' EXIT
cd /vm && mkdir -p pkg && : >serial.log
echo "== container: qemu, swtpm"
pacman -Syu --noconfirm --needed --cachedir /vm/pkg qemu-base qemu-hw-display-virtio-{vga,gpu} edk2-ovmf swtpm python git >/dev/null

if [[ ${1:-} != oracle ]]; then
  echo "== ISO"
  URL=https://geo.mirror.pkgbuild.com/iso/latest
  curl -fsSL $URL/sha256sums.txt | grep ' archlinux-x86_64.iso$' >iso.sha256
  sha256sum -c --status iso.sha256 2>/dev/null || { curl -fsSL -o archlinux-x86_64.iso $URL/archlinux-x86_64.iso; sha256sum -c iso.sha256; }
  bsdtar -xf archlinux-x86_64.iso arch/boot/x86_64 loader/entries
  rm -rf tpm arch.* && mkdir tpm
  cp /usr/share/edk2/x64/OVMF_VARS.4m.fd vars.fd
  qemu-img create -qf qcow2 disk.qcow2 512110190592 # = G14 nvme0n1
else
  cp arch.vars.fd vars.fd && rm -rf tpm && cp -a arch.tpm tpm
  qemu-img create -qf qcow2 -b arch.qcow2 -F qcow2 disk.qcow2
fi

echo "== serve repo (working tree) on 10.0.2.2:8000"
rm -rf /srv /tmp/w && mkdir /srv && cp -r /repo /tmp/w && rm -rf /tmp/w/.git
git -C /tmp/w init -q && git -C /tmp/w add -A && git -C /tmp/w -c user.name=t -c user.email=t@t commit -qm test
git clone -q --bare /tmp/w /srv/oracle.git && git -C /srv/oracle.git update-server-info
cp /repo/install.sh /repo/archinstall.json /srv/
cat >/srv/s1.sh <<'EOF'
#!/bin/bash
systemctl is-system-running --wait
exec setsid -c bash -c 'curl -fsSL http://10.0.2.2:8000/install.sh | ORACLE_RAW=http://10.0.2.2:8000 bash -s -- --silent
echo "S1 rc=$?"; mkdir -p /esp && mount /dev/nvme0n1p1 /esp && sed -i "/^options/s/\$/ console=tty0 console=ttyS0,115200/" /esp/loader/entries/*.conf
grep -H . /esp/loader/entries/*.conf; umount /esp; echo S1 DONE; poweroff' <>/dev/ttyS0 >&0 2>&0
EOF
python -m http.server -d /srv 8000 >/dev/null 2>&1 &

STAGE=${1:-all} python -u - <<'PY'
import os, re, select, socket, subprocess, sys, time
PW = 'oracle-test-pw'
LUKS = r'(?i)passphrase for [^\r\n]*: '
log = open('/vm/serial.log', 'ab')

class VM:
    def __init__(s, extra):
        subprocess.run(['swtpm', 'socket', '--tpm2', '--tpmstate', 'dir=/vm/tpm', '--daemon',
                        '--ctrl', 'type=unixio,path=/vm/tpm.sock'], check=True)
        s.p = subprocess.Popen(['qemu-system-x86_64', '-machine', 'q35,accel=kvm', '-cpu', 'host', '-smp', '4', '-m', '4096',
            '-drive', 'if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd',
            '-drive', 'if=pflash,format=raw,file=/vm/vars.fd',
            '-drive', 'if=none,id=d0,file=/vm/disk.qcow2', '-device', 'nvme,drive=d0,serial=oracle',
            '-chardev', 'socket,id=tpm,path=/vm/tpm.sock', '-tpmdev', 'emulator,id=tpm0,chardev=tpm', '-device', 'tpm-crb,tpmdev=tpm0',
            '-nic', 'user,model=virtio-net-pci', '-device', 'virtio-vga', '-display', 'none',
            '-monitor', 'unix:/vm/mon.sock,server=on,wait=off', '-serial', 'stdio', *extra],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        s.buf = b''

    def expect(s, pats, timeout, answers=()):
        """wait for one of pats (regex); answer prompts in answers [(regex, text)] meanwhile"""
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
                sys.exit(f'!! timeout waiting for {pats}\n--- serial tail ---\n{s.buf[-3000:].decode(errors="replace")}')
            if select.select([s.p.stdout], [], [], 1)[0]:
                d = os.read(s.p.stdout.fileno(), 65536)
                if not d:
                    sys.exit(f'!! qemu exited ({s.p.wait()}) waiting for {pats}\n--- serial tail ---\n{s.buf[-3000:].decode(errors="replace")}')
                log.write(d); log.flush()
                s.buf = s.buf[-200000:] + d

    def send(s, text):  # Enter = CR, like a real terminal
        time.sleep(0.5); s.p.stdin.write(text.replace('\n', '\r').encode()); s.p.stdin.flush()

    def sh(s, cmd, timeout=300, answers=(), show=60):
        s.buf = b''
        s.send(cmd + '; echo __RC=$?__\n')
        _, m = s.expect([r'__RC=(\d+)__'], timeout, answers)
        out = re.sub(r'\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\r', '', s.prev(m)).strip()
        if show:
            print(f'$ {cmd}\n' + '\n'.join(out.splitlines()[-show:]) + f'\n[rc={m[1].decode()}]', flush=True)
        return int(m[1]), out

    def prev(s, m):
        return m.string[:m.start()].decode(errors='replace').split('__RC=$?__', 1)[-1]

    def mon(s, cmd):
        c = socket.socket(socket.AF_UNIX); c.connect('/vm/mon.sock'); time.sleep(0.3); c.recv(4096)
        c.sendall(cmd.encode() + b'\n'); time.sleep(0.3); c.close()

    def keys(s, text):
        names = {'-': 'minus', '\n': 'ret', ' ': 'spc', '.': 'dot', '/': 'slash'}
        for ch in text:
            s.mon('sendkey ' + names.get(ch, ch)); time.sleep(0.05)

    def login(s, seen=False):
        seen or s.expect([r'oracle login:'], 300)
        s.send('son\n'); s.expect([r'Password:'], 60); s.send(PW + '\n')
        s.expect([r'\$ $'], 60); s.sh('set -o pipefail', show=0)

def step(t): print(f'\n== {t}', flush=True)
ok = {}

if os.environ['STAGE'] != 'oracle':
    step('stage 1: boot ISO, curl install.sh | bash (ISO mode → archinstall --silent)')
    opts = re.search(r'^options (.*)$', open('/vm/loader/entries/01-archiso-linux.conf').read(), re.M)[1]
    vm = VM(['-cdrom', '/vm/archlinux-x86_64.iso', '-kernel', '/vm/arch/boot/x86_64/vmlinuz-linux',
             '-initrd', '/vm/arch/boot/x86_64/initramfs-linux.img',
             '-append', f'{opts} script=http://10.0.2.2:8000/s1.sh console=ttyS0,115200 systemd.mask=serial-getty@ttyS0.service'])
    vm.expect([r'Password for son, root, disk: '], 600); vm.send(PW + '\n')
    vm.expect([r'Again: '], 30); vm.send(PW + '\n')
    _, m = vm.expect([r'S1 rc=(\d+)'], 3600)
    print(f'archinstall rc={m[1].decode()}')
    _, m = vm.expect([r'S1 DONE'], 120)
    print(re.sub(r'\r', '', vm.prev(m)).strip())
    vm.p.wait(120)
    os.system('cd /vm && mv disk.qcow2 arch.qcow2 && qemu-img create -qf qcow2 -b arch.qcow2 -F qcow2 disk.qcow2'
              ' && cp vars.fd arch.vars.fd && cp -a tpm arch.tpm')

step('stage 2: boot installed Arch, LUKS password on serial')
vm = VM([])
vm.expect([LUKS], 300); vm.send(PW + '\n')
vm.login()
vm.sh('cat /proc/cmdline; lsblk -o NAME,TYPE,FSTYPE,MOUNTPOINTS; grep -E "^HOOKS" /etc/mkinitcpio.conf')
step('stage 3: curl install.sh | bash (Oracle + TPM enroll)')
sudo = [(r'\[sudo\] password for son:', PW), (r'Disk password: ', PW)]
INSTALL = 'curl -fsSL http://10.0.2.2:8000/install.sh | ORACLE_REPO=http://10.0.2.2:8000/oracle.git bash'
rc, out = vm.sh(INSTALL, 5400, sudo, 40)
ok['install.sh rc=0'] = rc == 0 and 'done. Reboot' in out
step('stage 4: reboot, expect NO password prompt')
vm.buf = b''
vm.send('sudo reboot\n')
i, m = vm.expect([LUKS, r'oracle login:'], 600, sudo)
print('\n'.join(l for l in re.sub(r'\x1b\[[0-9;]*m|\r', '', m.string.decode(errors='replace')).splitlines()
                if re.search(r'Cryptography|passphrase|Encrypted Volumes', l)))
ok['boot without password (TPM)'] = i == 1
if i == 0:
    vm.send(PW + '\n'); vm.expect([r'oracle login:'], 300)
vm.login(seen=True)
step('checks')
vm.sh('sudo -v', 60, sudo, show=0)
rc, out = vm.sh('sudo systemd-cryptenroll /dev/nvme0n1p2; cat /etc/mkinitcpio.conf.d/oracle-tpm.conf; sudo grep -v "^#" /etc/crypttab')
ok['TPM2 + recovery keyslots'] = re.search(r'\d+ recovery', out) and re.search(r'\d+ tpm2', out)
rc, out = vm.sh('systemctl is-active NetworkManager systemd-resolved; readlink /etc/resolv.conf')
ok['NetworkManager + resolved active'] = out.count('active') == 2 and 'inactive' not in out
rc, _ = vm.sh('resolvectl query archlinux.org && curl -sSI https://archlinux.org | head -1')
ok['DNS'] = rc == 0
rc, _ = vm.sh('pacman -Q hyprland brave-origin-bin ghostty')
ok['packages'] = rc == 0
rc, out = vm.sh('Hyprland --verify-config --config ~/.config/hypr/hyprland.lua 2>&1 | tail -n 3')
ok['hyprland.lua verifies'] = rc == 0 and 'config ok' in out
rc, out = vm.sh(INSTALL, 1800, sudo, 6)
ok['install.sh re-run (idempotent)'] = rc == 0 and 'already enrolled' in out
step('tty1 login via monitor sendkey')
vm.keys('son\n'); time.sleep(2); vm.keys(PW + '\n'); time.sleep(25)
rc, out = vm.sh('pgrep -a cage; pgrep -a tmux; loginctl list-sessions --no-legend')
ok['Shell mode after tty1 login (cage + ghostty + tmux)'] = rc == 0 and 'cage' in out and 'ghostty' in out and 'tmux' in out
vm.mon('screendump /vm/shell.png -f png')
vm.sh('oracle gui; sleep 25')
rc, out = vm.sh('pgrep -a Hyprland; pgrep -x cage; cat ~/.local/state/oracle/mode')
ok['oracle gui → Hyprland'] = 'Hyprland' in out and 'cage' not in out.split('Hyprland')[-1]
vm.mon('screendump /vm/gui.png -f png')
vm.sh('HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1) oracle shell; sleep 20')
rc, out = vm.sh('pgrep -a cage && tmux ls')
ok['oracle shell → back to Shell, tmux kept'] = rc == 0 and 'oracle' in out
vm.send('sudo poweroff\n'); vm.p.wait(120)
step('result')
for k, v in ok.items():
    print(('PASS ' if v else 'FAIL ') + k)
sys.exit(0 if all(ok.values()) else 1)
PY
