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
import glob, os, re, select, socket, subprocess, sys, time
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
                s.buf = s.buf[-400000:] + d

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
        if s.expect([r'\$ $', '❯'], 60)[0]: s.send('exec bash\n'); s.expect([r'\$ $'], 60)  # zsh + starship → bash for the checks
        s.sh('set -o pipefail', show=0)

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
BOOT = ('systemctl is-system-running --wait; systemd-analyze; systemd-analyze blame --no-pager | head -n 15;'
        ' systemd-analyze critical-chain --no-pager | head -n 25')
step('boot time before (this branch not applied yet): restart once, first boot already done')
vm.send('sudo reboot\n'); time.sleep(5); vm.login()
vm.sh(BOOT, 600, show=60)
INSTALL = 'curl -fsSL http://10.0.2.2:8000/install.sh | ORACLE_REPO=http://10.0.2.2:8000/oracle.git bash'
vm.sh('git -C ~/.local/share/oracle fetch -q http://10.0.2.2:8000/oracle.git && git -C ~/.local/share/oracle reset -q --hard FETCH_HEAD')  # served repo is new each run
rc, out = vm.sh(INSTALL, 1800, sudo, 6)
ok['install.sh re-run on the installed system (idempotent)'] = rc == 0 and 'already enrolled' in out
step('system logic: power button, battery, alerts, updates (no desktop yet)')
rc, out = vm.sh('busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandlePowerKey HandlePowerKeyLongPress; cat /etc/systemd/logind.conf.d/oracle-power.conf')
ok['logind: power key press ignored, long press powers off (live, no reboot)'] = 's "ignore"' in out and 's "poweroff"' in out
vm.mon('system_powerdown'); time.sleep(8)
rc, out = vm.sh('echo STILL-UP; journalctl -b -u systemd-logind --since -1min -o cat | tail -n 3')
ok['power button at the login screen: the machine keeps running'] = 'STILL-UP' in out and vm.p.poll() is None
rc, out = vm.sh('bash ~/.local/share/oracle/test/system.sh', 180, show=40)
ok['system.sh: battery rules, update check, alerts, idle steps, migration (fakes)'] = rc == 0 and 'system ok' in out
rc, out = vm.sh('systemctl show -p ActiveState -p Result oracle-power; journalctl -b -u oracle-power -o cat | tail -n 2; systemctl is-enabled oracle-power;'
                ' systemctl --user is-active oracle-watch.timer; timedatectl show -p NTP --value; pacman -Q pacman-contrib')
ok['battery watcher installed (no battery in the VM: exits quietly), alerts timer on, clock automatic'] = \
    'Result=success' in out and 'no battery' in out and re.search(r'^enabled$', out, re.M) and re.search(r'^active$', out, re.M) and re.search(r'^yes$', out, re.M)
rc, out = vm.sh('timeout 200 oracle update --check </dev/null; cat ~/.local/state/oracle/updates; git -C ~/.local/share/oracle status --short | head -n 3', 260)
ok['oracle update --check (real): counts, writes the state file, installs nothing'] = 'packages=' in out and 'checked=' in out
rc, _ = vm.sh('pacman -Q waybar fuzzel swaync hypridle swaybg fwupd fcitx5-bamboo loupe bluez micro nautilus noto-fonts')
ok['desktop packages'] = rc == 0
rc, out = vm.sh('Hyprland --verify-config --config ~/.config/hypr/hyprland.lua 2>&1 | tail -n 3')
ok['new hyprland config verifies'] = rc == 0 and 'config ok' in out
rc, out = vm.sh('sudo snapper -c root list | tail -n 2; sudo btrfs subvolume show /.snapshots >/dev/null && echo SNAPDIR', 60, sudo)
ok['snapshots set up'] = rc == 0 and 'SNAPDIR' in out
rc, out = vm.sh('sudo pacman -S --noconfirm cowsay >/dev/null; command -v cowsay; printf "1\\n" | oracle rollback; command -v cowsay || echo GONE', 600, sudo)
ok['oracle rollback takes back an update'] = 'GONE' in out and 'rolled back' in out
rc, out = vm.sh('sleep 10; sudo grep -E "^ */|editor_enabled|subvol" /boot/limine.conf | head -n 30; efibootmgr | grep -i limine; bootctl is-installed 2>&1 | tail -n 1', 120, sudo)
ok['Limine boot menu: snapshots listed, editor off'] = 'editor_enabled: no' in out and 'Snapshots' in out and '.snapshots/' in out
rc, out = vm.sh('oracle set scale 1.25; oracle set keyboard de; oracle get scale; Hyprland --verify-config --config ~/.config/hypr/hyprland.lua 2>&1 | tail -n 2;'
                ' oracle set keyboard; oracle set scale; grep -c oracle/ghostty ~/.config/ghostty/config')
ok['settings file: Hyprland reads it, ghostty includes it'] = '1.25' in out and 'config ok' in out and re.search(r'^1$', out, re.M)
vm.sh('oracle set nightlight always; oracle set wallpaper $(ls /usr/share/hypr/*.png | head -1)')
step('tty1 login via monitor sendkey (fresh state: welcome guide first)')
vm.sh('rm -f ~/.local/state/oracle/done/welcome; ls ~/.local/state/oracle/migrations | grep -c .')
vm.keys('son\n'); time.sleep(2); vm.keys(PW + '\n'); time.sleep(25)
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
vm.mon('system_powerdown'); time.sleep(8)
rc, out = vm.sh('pgrep -a cage | head -n 1; echo STILL-UP; pgrep -af swayidle')
ok['Shell mode: power button does nothing, cage keeps running'] = 'cage' in out and 'STILL-UP' in out and vm.p.poll() is None
ok['Shell mode idle: 2/3 min on battery, 5/7 plugged in'] = all(x in out for x in ('timeout 120', 'idle dim battery', 'timeout 180', 'idle off battery', 'timeout 300', 'timeout 420', 'idle wake'))
vm.sh('printf "packages=23\\noracle=0\\nchecked=$(date +%s)\\n" >~/.local/state/oracle/updates;'
      ' echo "Disk almost full. Disk is 92% full. Free some space: oracle files" >~/.local/state/oracle/alerts; tmux select-window -t oracle:1; sleep 13', 60, show=0)
rc, out = vm.sh('tmux capture-pane -p -t oracle:1 | grep -E "pdate|Disk is"; tmux new -d -s tall -x 160 -y 60 oracle-home; sleep 5;'  # this VM screen is too short for the whole dashboard
                ' tmux capture-pane -p -t tall | grep -E "pdate|Disk is"; tmux kill-session -t tall')
ok['dashboard: update count in the footer, alert line above it (160x60 pane)'] = '[u]pdate 23' in out and 'Disk is 92% full. Free some space: oracle files' in out
vm.mon('screendump /vm/sys-shell-alert.png -f png')
vm.sh('rm -f ~/.local/state/oracle/alerts ~/.local/state/oracle/updates', show=0)
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
vm.sh('pkill -f oracle.manual; setsid -f fuzzel --show drun &>/dev/null; sleep 3', 30, show=0)
vm.mon('screendump /vm/look-launcher.png -f png')
rc, out = vm.sh('hyprctl layers | grep namespace | sort -u')
ok['look: launcher layer is "launcher" (blur rule matches)'] = 'launcher' in out
vm.sh('pkill -x fuzzel; for i in 1 2; do notify-send "Test notification $i" "Tiếng Việt: Xin chào, đã lưu ảnh. 4,243 photos synced, this line is longer to see wrapping."; done; sleep 3', 30, show=0)
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
vm.sh('setsid -f nautilus &>/dev/null; sleep 10', 30, show=0)
vm.mon('screendump /vm/look-gtk.png -f png')
vm.sh(VMENV + '; oracle set wallpaper ~/.local/share/oracle/default/wallpapers/dunes.jpg; oracle wall; sleep 4', 30, show=0)
vm.mon('screendump /vm/look-app.png -f png')  # bar with an app in use
vm.sh('pkill -x nautilus; sleep 3', 30, show=0)
vm.mon('screendump /vm/look-idle.png -f png')  # empty desktop: bar + Oracle's own wallpaper
step('system logic: desktop')
vm.sh('set +H', show=0)  # no ! history expansion in the fakes below
vm.sh(VMENV + '; bash ~/.local/share/oracle/migrations/1794383700.sh; sleep 3', 60)  # = what oracle update does
rc, out = vm.sh(VMENV + '; cmp ~/.config/hypr/hypridle.conf ~/.local/share/oracle/config/hypr/hypridle.conf && echo IDLE-NEW; grep -c "Shut down now" ~/.config/fuzzel/power-menu.sh;'
                ' pgrep -x hypridle && echo HYPRIDLE-UP; hyprctl configerrors; grep -c XF86PowerOff ~/.local/share/oracle/default/hypr/modules/binds.lua')
ok['desktop: migration put the new idle timers + power menu in place, hypridle restarted, no config errors'] = \
    'IDLE-NEW' in out and 'HYPRIDLE-UP' in out and re.search(r'^1$', out, re.M) and 'error' not in out.lower()
rc, out = vm.sh(VMENV + '; pkill -x hypridle; sleep 1; timeout 4 hypridle -v >/tmp/hi.log 2>&1; echo rc=$?; grep -ciE "error|invalid|unknown" /tmp/hi.log; grep -c "oracle idle" /tmp/hi.log; setsid -f hypridle &>/dev/null; sleep 1; pgrep -x hypridle >/dev/null && echo HYPRIDLE-UP')
ok['hypridle runs the new config (still up after 4 s, no config errors)'] = 'rc=124' in out and re.search(r'^0$', out, re.M) and 'HYPRIDLE-UP' in out
IDLET = (VMENV + "; pkill -x hypridle; T=$(mktemp -d); printf 'listener {\\n timeout = 4\\n on-timeout = touch %s/fired\\n}\\n' $T >$T/c.conf;"
         " setsid -f hypridle -c $T/c.conf &>$T/log; sleep 1; systemd-inhibit --what=idle --why=video sleep 12 & sleep 9;"
         " [ -e $T/fired ] && echo FIRED-WHILE-HELD || echo HELD; wait; sleep 7; [ -e $T/fired ] && echo FIRED-AFTER;"
         " pkill -x hypridle; setsid -f hypridle &>/dev/null; grep -i inhibit $T/log | head -n 6")
rc, out = vm.sh(IDLET, 120)
ok['idle: an app holding an idle inhibitor (a video) keeps the screen on; timers run again after'] = 'HELD' in out and 'FIRED-WHILE-HELD' not in out and 'FIRED-AFTER' in out
vm.mon('system_powerdown'); time.sleep(4)
vm.mon('screendump /vm/sys-power-menu.png -f png')
rc, out = vm.sh('pgrep -af fuzzel; echo STILL-UP')
ok['desktop: power button opens the power menu'] = 'fuzzel' in out
ok['desktop: power button does not shut down'] = 'STILL-UP' in out and vm.p.poll() is None
vm.mon('sendkey esc'); time.sleep(2)
rc, out = vm.sh('pgrep -x fuzzel || echo MENU-GONE; echo STILL-UP')
ok['Esc closes the power menu, machine keeps running'] = 'MENU-GONE' in out and 'STILL-UP' in out
N = '/tmp/notes.log'
MATCH = "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"
MON = (VMENV + f'; pkill -f "busctl --user monitor"; setsid -f busctl --user monitor --match "{MATCH}" >{N} 2>&1; sleep 1')
def notes(): return re.findall(r'STRING "([^"]*)"', vm.sh(f'cat {N}', show=0)[1])
vm.sh(MON + '; printf "packages=0\\noracle=0\\nchecked=$(date +%s)\\n" >~/.local/state/oracle/updates; oracle watch; sleep 1; swaync-client -C', 60)  # whatever is already wrong: said now
vm.sh(MON + '; swaync-client -C; ORACLE_DISK_ALERT=1 oracle watch; sleep 2', 60)
vm.mon('screendump /vm/sys-alert-disk.png -f png')
n = notes(); print(n)
ok['alert: disk almost full, one plain sentence + the fix'] = any(re.match(r'Disk is \d+% full\. Free some space: oracle files$', x) for x in n)
vm.sh(MON + '; swaync-client -C; cp /usr/bin/sleep /tmp/crashtest; (ulimit -c unlimited; /tmp/crashtest 60 & p=$!; sleep 1; kill -SEGV $p; wait $p); sleep 5;'
      ' coredumpctl list --no-pager --no-legend | tail -n 1; oracle watch; sleep 2', 90)
vm.mon('screendump /vm/sys-alert-crash.png -f png')
n = notes(); print(n)
ok['alert: app crash → "Crashtest quit unexpectedly."'] = 'Crashtest quit unexpectedly.' in n
vm.sh(MON + '; systemd-run --user -q --unit=oracle-test-broken false; sleep 2; oracle watch; docker stop dockge >/dev/null; ORACLE_WATCH_GRACE=0 oracle watch;'
      ' mkdir -p /tmp/fk; echo "echo portal" >/tmp/fk/nmcli; chmod +x /tmp/fk/nmcli; PATH=/tmp/fk:$PATH oracle watch; sleep 2', 120)
n = notes(); print(n)
ok['alert: failed service, with the fix'] = 'The service oracle-test-broken stopped working. Check it with: oracle doctor' in n
ok['alert: server app down, with the fix'] = 'The home server app Dockge has stopped. Check it with: oracle doctor' in n
ok['alert: Wi-Fi sign-in page, with an Open action'] = 'This Wi-Fi needs a sign-in.' in n and 'default' in n
vm.sh(MON + '; ORACLE_DISK_ALERT=1 ORACLE_WATCH_GRACE=0 PATH=/tmp/fk:$PATH oracle watch; sleep 2', 60, show=0)
ok['alerts: the same ones again → no repeat today'] = notes() == []
vm.sh('docker start dockge >/dev/null; systemctl --user reset-failed oracle-test-broken; pkill -f "notify-send -a Oracle"; oracle watch; cat ~/.local/state/oracle/alerts', 60)
vm.sh(MON + '; mkdir -p /tmp/ps/BAT0 /tmp/ps/AC0; echo Battery >/tmp/ps/BAT0/type; echo Mains >/tmp/ps/AC0/type; echo 0 >/tmp/ps/AC0/online;'
      ' echo 20 >/tmp/ps/BAT0/capacity; echo Discharging >/tmp/ps/BAT0/status;'
      ' sudo setsid -f env ORACLE_POWER_SUPPLY=/tmp/ps ORACLE_POWER_TICK=1 ORACLE_POWER_GRACE=6 ORACLE_POWEROFF="touch /tmp/ps/POWEROFF" /usr/local/bin/oracle-power >/tmp/power.log 2>&1;'
      ' sleep 3; echo 10 >/tmp/ps/BAT0/capacity; sleep 3', 60, sudo)
vm.mon('screendump /vm/sys-alert-battery.png -f png')
vm.sh('echo 4 >/tmp/ps/BAT0/capacity; sleep 3; echo 1 >/tmp/ps/AC0/online; sleep 4; sudo pkill -f /usr/local/bin/oracle-power; cat /tmp/power.log; ls /tmp/ps', 60, sudo)
n = notes(); print(n)
ok['battery (root → your desktop): 20%, 10%, 4% countdown, cancelled when plugged in'] = all(x in n for x in ('Battery at 20%', 'Plug in soon.', 'Battery at 10%', 'Plug in now.',
    'Shutting down in 6 seconds to keep your data safe. Plug in to cancel.', 'Shutdown cancelled.')) and 'POWEROFF' not in vm.sh('ls /tmp/ps', show=0)[1]
vm.sh(MON + '; mkdir -p /tmp/fu; printf "#!/bin/sh\\nprintf \\"linux 1 -> 2\\\\nmesa 1 -> 2\\\\n\\"\\n" >/tmp/fu/checkupdates; chmod +x /tmp/fu/checkupdates; cat /tmp/fu/checkupdates;'
      ' rm -f ~/.local/state/oracle/updates*; PATH=/tmp/fu:$PATH oracle update --check; PATH=/tmp/fu:$PATH oracle update --check; sleep 2; cat ~/.local/state/oracle/updates', 200)
n = notes(); print(n)
ok['update notice: one, quiet, plain words; second check says nothing'] = n.count('Updates are ready') == 1 and any(re.match(r'\d+ packages?( and a newer Oracle)?\. Run oracle update when it suits you\.$', x) for x in n)
rc, out = vm.sh('oracle doctor 2>&1 | grep -E "power button|battery watch|alerts|update check|clock"', 200, sudo)
ok['doctor: power button, alerts, update check, clock green (battery watch: no battery here)'] = \
    all(re.search(rf'ok +{x}', clean(out)) for x in ('power button', 'alerts', 'update check', 'clock')) and 'no battery here' in out
vm.sh('pkill -f "busctl --user monitor"; swaync-client -C', show=0)
vm.sh('HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1) oracle shell; sleep 20')
rc, out = vm.sh('export HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1); hyprctl clients | grep -c "class: oracle.shell"; hyprctl monitors | grep "special workspace"; hyprctl configerrors; tmux ls')
ok['oracle shell → Shell over the desktop (Hyprland stays), tmux kept'] = 'special:shell' in out and 'oracle' in out.split('special:shell')[-1] and re.search(r'^1$', out, re.M)
step('boot time after (this branch applied)')
vm.send('sudo reboot\n'); time.sleep(5); vm.login()
rc, out = vm.sh(BOOT, 600, show=60)
rc, out = vm.sh('busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandlePowerKey')
vm.mon('system_powerdown'); time.sleep(8)
rc, out2 = vm.sh('echo STILL-UP')
ok['after a restart: power button still ignored at the login screen'] = 's "ignore"' in out and 'STILL-UP' in out2
step('battery at 3%, no charger: real clean shutdown (last step)')
vm.sh('mkdir -p /tmp/ps/BAT0 /tmp/ps/AC0; echo Battery >/tmp/ps/BAT0/type; echo Mains >/tmp/ps/AC0/type; echo 0 >/tmp/ps/AC0/online;'
      ' echo 3 >/tmp/ps/BAT0/capacity; echo Discharging >/tmp/ps/BAT0/status; sudo -v', 60, sudo, show=0)
vm.buf = b''; vm.send('sudo ORACLE_POWER_SUPPLY=/tmp/ps ORACLE_POWER_GRACE=6 /usr/local/bin/oracle-power\n')
try:
    _, m = vm.expect([r'reboot: Power down'], 240)
    tail = clean(m.string.decode(errors='replace'))
    print('\n'.join(l for l in tail.splitlines() if re.search(r'Battery at|shutting down|docker|Docker|Power down', l))[-1500:])
    ok['battery 3%: clean shutdown after the wait (docker stopped first)'] = vm.p.wait(60) is not None and 'shutting down now' in tail
except SystemExit as e:
    print(e); ok['battery 3%: clean shutdown after the wait (docker stopped first)'] = False
step('result')
for k, v in ok.items():
    print(('PASS ' if v else 'FAIL ') + k)
sys.exit(0 if all(ok.values()) else 1)
PY
