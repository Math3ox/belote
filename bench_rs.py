"""Compare le temps de la version assembleur (belote.exe -sim) et du port Rust (WSL) sur les memes parties."""
import subprocess, time, re, sys
def asm(cfg):
    t = time.perf_counter()
    subprocess.run(['./belote.exe', '-sim'] + cfg.split(), check=True)
    dt = time.perf_counter() - t
    last = open('sim.log').read().strip().split('\n')[-1]
    return dt, last
def rs(cfg):
    out = subprocess.run(['sh', './rs.sh'] + cfg.split(), capture_output=True, text=True).stdout
    m = re.search(r'temps ([0-9.]+) s', out)
    last = open('sim_rs.log').read().strip().split('\n')[-1]
    return float(m.group(1)), last
tests = [
    ('normal vs normal, 4 joueurs, 20000 parties', '20000 1 4 1 1 0'),
    ('normal vs normal, 2 joueurs, 20000 parties', '20000 2 2 1 1 0'),
    ('difficile vs normal, 4 joueurs, 300 parties', '300 3 4 2 1 0'),
    ('difficile vs difficile, 2 joueurs, 200 parties', '200 4 2 2 2 0'),
]
for name, cfg in tests:
    ta = [asm(cfg) for _ in range(3)]
    tr = [rs(cfg) for _ in range(3)]
    a = min(t for t, _ in ta); r = min(t for t, _ in tr)
    same = ta[0][1] == tr[0][1]
    print('%-50s asm %7.3f s | rust %7.3f s | rust/asm = %.2f | resultat %s %s' % (name, a, r, r / a, 'identique' if same else 'DIFFERENT', ta[0][1]), flush=True)
    print('    asm :', ['%.3f' % t for t, _ in ta], ' rust :', ['%.3f' % t for t, _ in tr], flush=True)
