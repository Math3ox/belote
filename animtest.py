"""Filme l'envoi d'une carte : pilote le jeu en mode auto et capture une rafale d'images, puis fait une planche contact."""
import subprocess, sys, time, os, struct
sys.argv = ['x']
exec(open('uitest.py').read().split('def main')[0])
g = Game()
time.sleep(1.0)
g.key(0x55)
t0 = time.time()
while time.time() - t0 < 40:
    s = g.state()
    if s and s[0] == 3 and s[6] == 0 and s[1] in (0, 1):
        break
    time.sleep(0.1)
print('phase de jeu', s)
frames = []
for i in range(16):
    if os.path.exists(SHOT): os.remove(SHOT)
    g.key(0x7B)
    time.sleep(0.07)
    for _ in range(20):
        if os.path.exists(SHOT):
            time.sleep(0.03)
            try:
                d = open(SHOT, 'rb').read()
                if len(d) > 3000000: break
            except Exception: pass
        time.sleep(0.01)
    frames.append(open(SHOT, 'rb').read())
g.close()
# planche contact : recadrage de la table, reduction x2, 4 colonnes
W, H = 1100, 800
x0, y0, cw, ch = 300, 200, 500, 360
sc = 2
cols = 4
rows = (len(frames) + cols - 1) // cols
tw, th = cw // sc, ch // sc
sheet = bytearray(cols * tw * rows * th * 4)
for n, d in enumerate(frames):
    off = struct.unpack_from('<I', d, 10)[0]
    for y in range(th):
        sy = y0 + y * sc
        row = d[off + (sy * W + x0) * 4: off + (sy * W + x0 + cw) * 4]
        dst = ((n // cols) * th + y) * cols * tw * 4 + (n % cols) * tw * 4
        for x in range(tw):
            sheet[dst + x * 4: dst + x * 4 + 4] = row[x * sc * 4: x * sc * 4 + 4]
w2, h2 = cols * tw, rows * th
png_data = bytes(sheet)
import zlib
rowsb = []
for y in range(h2):
    r = png_data[y * w2 * 4:(y + 1) * w2 * 4]
    rgb = bytearray(w2 * 3); rgb[0::3] = r[2::4]; rgb[1::3] = r[1::4]; rgb[2::3] = r[0::4]
    rowsb.append(b'\x00' + bytes(rgb))
def chunk(t, c):
    x = struct.pack('>I', len(c)) + t + c
    return x + struct.pack('>I', zlib.crc32(t + c) & 0xffffffff)
open('anim.png', 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w2, h2, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(b''.join(rowsb), 6)) + chunk(b'IEND', b''))
print('planche', w2, h2)
