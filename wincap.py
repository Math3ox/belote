"""Capture UNIQUEMENT la fenêtre du jeu (PrintWindow), jamais l'écran entier. Usage : python wincap.py exe sortie.png [touches hex...]"""
import ctypes, subprocess, struct, sys, time, zlib, os
from ctypes import wintypes
user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32
user32.SetProcessDPIAware()
HERE = os.path.dirname(os.path.abspath(__file__))

def png(path, w, h, bgra):
    rows = []
    for y in range(h):
        row = bgra[y * w * 4:(y + 1) * w * 4]
        rgb = bytearray(w * 3)
        rgb[0::3] = row[2::4]; rgb[1::3] = row[1::4]; rgb[2::3] = row[0::4]
        rows.append(b'\x00' + bytes(rgb))
    def chunk(t, c):
        x = struct.pack('>I', len(c)) + t + c
        return x + struct.pack('>I', zlib.crc32(t + c) & 0xffffffff)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(b''.join(rows), 6)) + chunk(b'IEND', b''))

def capture(hwnd, path):
    r = wintypes.RECT(); user32.GetClientRect(hwnd, ctypes.byref(r))
    w, h = r.right, r.bottom
    hdc = user32.GetDC(hwnd)
    mdc = gdi32.CreateCompatibleDC(hdc)
    bmp = gdi32.CreateCompatibleBitmap(hdc, w, h)
    gdi32.SelectObject(mdc, bmp)
    user32.PrintWindow(hwnd, mdc, 3)         # PW_CLIENTONLY | PW_RENDERFULLCONTENT
    class BIH(ctypes.Structure):
        _fields_ = [('s', wintypes.DWORD), ('w', wintypes.LONG), ('h', wintypes.LONG), ('p', wintypes.WORD), ('b', wintypes.WORD),
                    ('c', wintypes.DWORD), ('si', wintypes.DWORD), ('x', wintypes.LONG), ('y', wintypes.LONG), ('u', wintypes.DWORD), ('i', wintypes.DWORD)]
    bi = BIH(40, w, -h, 1, 32, 0, w * h * 4, 0, 0, 0, 0)
    buf = (ctypes.c_ubyte * (w * h * 4))()
    gdi32.GetDIBits(mdc, bmp, 0, h, buf, ctypes.byref(bi), 0)
    png(path, w, h, bytes(buf))
    print('fenetre %dx%d -> %s' % (w, h, path))

if __name__ == '__main__':
    p = subprocess.Popen([os.path.join(HERE, sys.argv[1])], cwd=HERE)
    time.sleep(1.5)
    hwnd = user32.FindWindowW('BeloteWin', None)
    for k in sys.argv[3:]:
        user32.PostMessageW(hwnd, 0x100, int(k, 16), 0); time.sleep(1.2)
    capture(hwnd, os.path.join(HERE, sys.argv[2]))
    user32.PostMessageW(hwnd, 0x100, 0x1B, 0); time.sleep(0.5)
    user32.PostMessageW(hwnd, 0x100, 0x1B, 0); time.sleep(0.5)
    if p.poll() is None: p.kill()
