"""Deux instances de belote.exe jouent en ligne (127.0.0.1) en mode automatique (U) ; on compare leurs états.
Usage : python nettest.py [np] [duree]"""
import ctypes, subprocess, sys, time, os
user32 = ctypes.windll.user32
user32.SetProcessDPIAware()
HERE = os.path.dirname(os.path.abspath(__file__))
np_ = int(sys.argv[1]) if len(sys.argv) > 1 else 2
dur = float(sys.argv[2]) if len(sys.argv) > 2 else 40
ng = int(sys.argv[3]) if len(sys.argv) > 3 else 1
cfg = os.path.join(HERE, 'belote.cfg')
if os.path.exists(cfg): os.remove(cfg)


def windows():
    res = []
    h = 0
    while True:
        h = user32.FindWindowExW(None, h, 'BeloteWin', None)
        if not h: break
        res.append(h)
    return res


def key(h, vk): user32.PostMessageW(h, 0x100, vk, 0)
def char(h, c): user32.PostMessageW(h, 0x102, ord(c) if isinstance(c, str) else c, 0)


def title(h):
    buf = ctypes.create_unicode_buffer(200)
    key(h, 0x44); time.sleep(0.15)
    user32.GetWindowTextW(h, buf, 200)
    return buf.value


procs = []
def start():
    p = subprocess.Popen([os.path.join(HERE, 'belote.exe')], cwd=HERE)
    procs.append(p)
    time.sleep(1.0)
    return windows()

w = start(); host = w[0]
if np_ == 2:
    key(host, 0x4A); time.sleep(0.5)
key(host, 0x4E); time.sleep(0.3); key(host, 0x48); time.sleep(0.5)
guests = []
for i in range(ng):
    w = start()
    g = [x for x in w if x != host and x not in guests][0]
    guests.append(g)
    key(g, 0x4E); time.sleep(0.3); key(g, 0x52); time.sleep(0.3)
    for c in '127.0.0.1': char(g, c)
    char(g, 13); time.sleep(1.0)
if np_ == 4 and ng < 3:
    key(host, 0x0D); time.sleep(1.0)      # démarre avec 1 invité + 2 bots
allw = [host] + guests
for h in allw: key(h, 0x55)               # mode auto
t0 = time.time()
mism = 0
samples = 0
while time.time() - t0 < dur:
    time.sleep(2.0)
    ts = [title(h) for h in allw]
    print(' | '.join(ts))
    if all(p.poll() is None for p in procs) is False:
        print('PLANTAGE'); break
sc = [t.split()[4:6] for t in ts]
print('scores finaux', sc)
for p in procs:
    if p.poll() is None: p.kill()
