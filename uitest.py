"""Pilote l'interface de belote.exe : lit l'état (touche D -> titre), clique à la place de l'humain,
capture des écrans (F12 -> PNG). Usage : python uitest.py [np] [duree_s]"""
import ctypes, subprocess, sys, time, os, struct, zlib

user32 = ctypes.windll.user32
user32.SetProcessDPIAware()
HERE = os.path.dirname(os.path.abspath(__file__))
SHOT = os.path.join(HERE, 'belote_shot.bmp')


def bmp_to_png(src, dst):
    d = open(src, 'rb').read()
    off = struct.unpack_from('<I', d, 10)[0]
    w, h = struct.unpack_from('<ii', d, 18)
    top_down = h < 0
    h = abs(h)
    rows = []
    for y in range(h):
        sy = y if top_down else h - 1 - y
        row = d[off + sy * w * 4: off + (sy + 1) * w * 4]
        rgb = bytearray(w * 3)
        rgb[0::3] = row[2::4]; rgb[1::3] = row[1::4]; rgb[2::3] = row[0::4]
        rows.append(b'\x00' + bytes(rgb))
    raw = b''.join(rows)

    def chunk(t, c):
        x = struct.pack('>I', len(c)) + t + c
        return x + struct.pack('>I', zlib.crc32(t + c) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) \
        + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b'')
    open(dst, 'wb').write(png)


class Game:
    def __init__(self):
        cfg = os.path.join(HERE, 'belote.cfg')
        if os.path.exists(cfg): os.remove(cfg)
        self.p = subprocess.Popen([os.path.join(HERE, 'belote.exe')], cwd=HERE)
        self.hwnd = 0
        for _ in range(50):
            self.hwnd = user32.FindWindowW('BeloteWin', None)
            if self.hwnd: break
            time.sleep(0.1)

    def key(self, vk):
        user32.PostMessageW(self.hwnd, 0x100, vk, 0)

    def click(self, x, y):
        user32.PostMessageW(self.hwnd, 0x201, 1, (int(y) << 16) | int(x))

    def state(self):
        buf = ctypes.create_unicode_buffer(160)
        self.key(0x44)
        time.sleep(0.12)
        user32.GetWindowTextW(self.hwnd, buf, 160)
        f = buf.value.split()
        try:
            return [int(v) for v in f[:8]] if len(f) >= 8 else None
        except ValueError:
            return None

    def shot(self, name):
        if os.path.exists(SHOT): os.remove(SHOT)
        self.key(0x7B)
        time.sleep(0.4)
        if os.path.exists(SHOT):
            bmp_to_png(SHOT, os.path.join(HERE, name))
            print('capture', name)

    def close(self):
        if self.p.poll() is None:
            self.key(0x1B)
            try: self.p.wait(timeout=3)
            except Exception: self.p.kill()


def main():
    np_ = int(sys.argv[1]) if len(sys.argv) > 1 else 4
    dur = float(sys.argv[2]) if len(sys.argv) > 2 else 120
    g = Game()
    if np_ == 2:
        g.key(0x4A); time.sleep(0.4)
    t0 = time.time()
    seen = set()
    while time.time() - t0 < dur:
        if g.p.poll() is not None:
            print('PLANTAGE code', g.p.returncode); return
        s = g.state()
        if not s: continue
        ph, turn, trump, taker, s0, s1, tn, npl = s
        if ph in (1, 2) and turn == 0:
            if ('bid%d' % ph) not in seen:
                time.sleep(0.5); g.shot('ui_bid%d.png' % ph); seen.add('bid%d' % ph)
            if ph == 1:
                g.click(630, 584)           # PASSER
            else:
                g.click(741, 584)           # PASSER (2e tour)
            time.sleep(0.6)
        elif ph == 3 and turn == 0:
            n = 8 - tn if npl == 4 else 7
            if 'play' not in seen and tn >= 1:
                time.sleep(0.5); g.shot('ui_play.png'); seen.add('play')
            for i in range(n):
                g.click(550 - (n - 1) * 39 + 78 * i, 692)
                time.sleep(0.15)
                s2 = g.state()
                if s2 and s2[1] != 0:
                    break
        elif ph in (5, 6):
            if ('end%d' % ph) not in seen:
                time.sleep(0.5); g.shot('ui_end%d.png' % ph); seen.add('end%d' % ph)
            g.key(0x20)
            time.sleep(0.5)
            if ph == 6: break
        else:
            time.sleep(0.2)
    print('fin', g.state())
    g.close()


main()
