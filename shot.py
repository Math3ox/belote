"""Pilote le jeu (target/release/belote.exe) pour les tests : lance, envoie des touches/clics, capture (F12 -> PNG).
Les réglages de l'utilisateur (belote.cfg à côté de l'exe) ne sont pas touchés : le jeu tourne depuis target/release.
Usage : python shot.py sortie.png [actions...]
  actions : wait:<s>  key:<code hex>  char:<lettres>  click:<x>,<y> (pixels de la fenêtre)  shot:<fichier.png>
  (ex. char:G wait:1 shot:galerie.png)"""
import ctypes, os, shutil, subprocess, sys, time

user32 = ctypes.windll.user32
user32.SetProcessDPIAware()
HERE = os.path.dirname(os.path.abspath(__file__))
EXE = os.path.join(HERE, 'target', 'release', 'belote.exe')
SHOT = os.path.join(HERE, 'belote_shot.png')
TITLE = 'Belote - jeu du bistro en 3D isométrique'


def key(hwnd, vk):
    # la fenêtre lit le code de touche physique (scan code) dans lParam
    sc = user32.MapVirtualKeyW(vk, 0)
    user32.PostMessageW(hwnd, 0x100, vk, (sc << 16) | 1)
    time.sleep(0.05)
    user32.PostMessageW(hwnd, 0x101, vk, (sc << 16) | 0xC0000001)


def capture(hwnd, dst):
    if os.path.exists(SHOT):
        os.remove(SHOT)
    key(hwnd, 0x7B)
    for _ in range(30):
        time.sleep(0.1)
        if os.path.exists(SHOT) and os.path.getsize(SHOT) > 0:
            time.sleep(0.2)
            shutil.move(SHOT, dst)
            print('ok', dst)
            return
    print('pas de capture', dst)


def main():
    out = sys.argv[1]
    acts = sys.argv[2:] or ['wait:1.0']
    p = subprocess.Popen([EXE], cwd=HERE)
    hwnd = 0
    for _ in range(80):
        hwnd = user32.FindWindowW(None, TITLE)
        if hwnd:
            break
        time.sleep(0.1)
    if not hwnd:
        print('fenetre introuvable'); p.kill(); return
    time.sleep(0.8)
    for a in acts:
        k, v = a.split(':', 1)
        if k == 'wait':
            time.sleep(float(v))
        elif k == 'key':
            key(hwnd, int(v, 16))
        elif k == 'char':
            for ch in v:
                user32.PostMessageW(hwnd, 0x102, ord(ch), 0)
                time.sleep(0.05)
        elif k == 'shot':
            capture(hwnd, v)
        elif k == 'click':
            x, y = [int(t) for t in v.split(',')]
            user32.PostMessageW(hwnd, 0x200, 0, (y << 16) | x)
            user32.PostMessageW(hwnd, 0x201, 1, (y << 16) | x)
            time.sleep(0.05)
            user32.PostMessageW(hwnd, 0x202, 0, (y << 16) | x)
    time.sleep(0.2)
    capture(hwnd, out)
    user32.PostMessageW(hwnd, 0x10, 0, 0)
    try:
        p.wait(timeout=3)
    except Exception:
        p.kill()


main()
