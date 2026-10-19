"""Pilote belote.exe pour les tests : lance, envoie des touches/clics, capture (F12) et convertit en PNG.
Usage : python shot.py sortie.png [actions...]
  actions : wait:<s>  key:<code hex>  click:<x>,<y>  (ex. key:20 wait:0.5 key:7B)"""
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
        rgb[0::3] = row[2::4]
        rgb[1::3] = row[1::4]
        rgb[2::3] = row[0::4]
        rows.append(b'\x00' + bytes(rgb))
    raw = b''.join(rows)

    def chunk(t, c):
        x = struct.pack('>I', len(c)) + t + c
        return x + struct.pack('>I', zlib.crc32(t + c) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) \
        + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b'')
    open(dst, 'wb').write(png)


def main():
    out = sys.argv[1]
    acts = sys.argv[2:] or ['wait:0.8', 'key:7B', 'wait:0.4']
    if os.path.exists(SHOT):
        os.remove(SHOT)
    p = subprocess.Popen([os.path.join(HERE, 'belote.exe')], cwd=HERE)
    hwnd = 0
    for _ in range(50):
        hwnd = user32.FindWindowW('BeloteWin', None)
        if hwnd:
            break
        time.sleep(0.1)
    if not hwnd:
        print('fenetre introuvable'); p.kill(); return
    for a in acts:
        k, v = a.split(':', 1)
        if k == 'wait':
            time.sleep(float(v))
        elif k == 'key':
            user32.PostMessageW(hwnd, 0x100, int(v, 16), 0)
        elif k == 'shot':
            if os.path.exists(SHOT): os.remove(SHOT)
            user32.PostMessageW(hwnd, 0x100, 0x7B, 0)
            time.sleep(0.4)
            if os.path.exists(SHOT): bmp_to_png(SHOT, v); print('ok', v)
        elif k == 'vals':
            buf = ctypes.create_unicode_buffer(128)
            user32.PostMessageW(hwnd, 0x100, 0x44, 0)
            time.sleep(0.3)
            user32.GetWindowTextW(hwnd, buf, 128)
            print('valeurs (joueur x3, bot x3, phase):', buf.value)
        elif k == 'click':
            x, y = [int(t) for t in v.split(',')]
            user32.PostMessageW(hwnd, 0x201, 1, (y << 16) | x)
    time.sleep(0.3)
    if p.poll() is None:
        user32.PostMessageW(hwnd, 0x100, 0x1B, 0)
        try:
            p.wait(timeout=3)
        except Exception:
            p.kill()
    if os.path.exists(SHOT):
        bmp_to_png(SHOT, out)
        print('ok', out)
    else:
        print('pas de capture (plantage ?) code', p.returncode)


main()
