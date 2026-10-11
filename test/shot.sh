#!/usr/bin/env bash
# Fast Shell-mode screenshot, no VM: tmux + dashboard in an archlinux container, drawn by pyte → PNG (JetBrains Mono, ghostty's default font).
# test/shot.sh [out.png] [seconds] [keys...]   e.g. test/shot.sh /tmp/ws2.png 20 '\x1b2'   (Alt+2). Uses your ~/.claude/projects for the heatmap.
set -euo pipefail
if [[ ! -f /.dockerenv ]]; then
  ROOT=$(cd "$(dirname "$0")/.." && pwd) OUT=$(realpath "${1:-shot.png}")
  C=(); [[ -d ~/.claude/projects ]] && C=(-v "$HOME/.claude/projects:/claude:ro")
  exec docker run --rm -e WAIT="${2:-30}" -e KEYS="${*:3}" -e NAME="${OUT##*/}" "${C[@]}" -v "$ROOT:/repo:ro" -v "${OUT%/*}:/out" archlinux:latest bash /repo/test/shot.sh
fi
pacman -Sy --noconfirm --needed tmux python-pillow python-pyte ttf-jetbrains-mono >/dev/null 2>&1
useradd -m son; H=/home/son; mkdir -p $H/.local/share $H/.local/bin $H/.config/tmux $H/.claude /etc/oracle
cp -r /repo $H/.local/share/oracle; ln -s $H/.local/share/oracle/bin/oracle $H/.local/bin/oracle
echo "source-file $H/.local/share/oracle/default/tmux.conf" >$H/.config/tmux/tmux.conf
[[ ! -d /claude ]] || cp -r /claude $H/.claude/projects
echo 50 >/etc/oracle/battery-limit; chown -R son $H
su son -w KEYS,WAIT,NAME -c "PATH=$H/.local/bin:\$PATH TZ=Asia/Ho_Chi_Minh python3 - /out/\$NAME" <<'PY'
import os, pty, sys, time, select, pyte
from PIL import Image, ImageDraw, ImageFont
cols, rows, wait, out = 128, 38, float(os.environ['WAIT']), sys.argv[1]
keys = os.environ.get('KEYS', '').split()
pyte.Screen.report_device_status = lambda s, *a, **k: None
scr = pyte.Screen(cols, rows); st = pyte.ByteStream(scr)
pid, fd = pty.fork()
if pid == 0:
    os.environ.update(TERM='xterm-256color', COLORTERM='truecolor', LINES=str(rows), COLUMNS=str(cols))
    os.execvp('bash', ['bash', '-lc', 'stty rows %d cols %d; exec oracle attach' % (rows, cols)])
end = time.time() + wait; ki = 0
while time.time() < end:
    r, _, _ = select.select([fd], [], [], 0.2)
    if r:
        try: st.feed(os.read(fd, 65536))
        except OSError: break
    if keys and ki < len(keys) and time.time() > end - wait / 2 + ki:
        os.write(fd, keys[ki].encode().decode('unicode_escape').encode()); ki += 1
f = ImageFont.truetype('/usr/share/fonts/TTF/JetBrainsMono-Regular.ttf', 17)
cw, ch = 10, 21
img = Image.new('RGB', (cols * cw + 16, rows * ch + 12), (10, 10, 10)); d = ImageDraw.Draw(img)
def col(c, default):
    if c == 'default': return default
    if isinstance(c, str) and len(c) == 6:
        try: return tuple(int(c[i:i+2], 16) for i in (0, 2, 4))
        except ValueError: pass
    named = {'black': (10,10,10), 'red': (139,46,46), 'cyan': (0,229,255), 'white': (200,200,200), 'brightblack': (74,74,74)}
    return named.get(c, default)
for y in range(rows):
    for x in range(cols):
        c = scr.buffer[y][x]
        fg, bg = col(c.fg, (200,200,200)), col(c.bg, (10,10,10))
        if c.reverse: fg, bg = bg, fg
        px, py = 8 + x * cw, 6 + y * ch
        if bg != (10,10,10): d.rectangle([px, py, px + cw - 1, py + ch - 1], fill=bg)
        if c.data.strip():
            ch_ = c.data
            if ch_ in '▁▂▃▄▅▆▇█':
                h = int(ch * ('▁▂▃▄▅▆▇█'.index(ch_) + 1) / 8); d.rectangle([px, py + ch - h, px + cw - 1, py + ch - 1], fill=fg)
            elif ch_ in '▏▎▍▌▋▊▉':
                w = int(cw * ('▏▎▍▌▋▊▉'.index(ch_) + 1) / 8); d.rectangle([px, py, px + w - 1, py + ch - 1], fill=fg)
            elif ch_ == '▕': d.rectangle([px + cw - 1 - cw // 8, py, px + cw - 1, py + ch - 1], fill=fg)
            elif ch_ in '░▒▓':
                a = {'░': .25, '▒': .5, '▓': .75}[ch_]; bc = tuple(int(bg[i] + (fg[i] - bg[i]) * a) for i in range(3))
                d.rectangle([px, py, px + cw - 1, py + ch - 1], fill=bc)
            else: d.text((px, py + 1), ch_, font=f, fill=fg)
        if c.underscore: d.line([px, py + ch - 2, px + cw, py + ch - 2], fill=fg)
img.save(out)
PY
