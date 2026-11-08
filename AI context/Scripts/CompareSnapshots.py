# Compare two SnapshotMeasures.ps1 outputs: numbers equal within a relative tolerance (float rounding, Double ->
# Currency), text exactly. Prints the sections that differ. Exit code 1 when a real difference is found.
#   python -I -X utf8 CompareSnapshots.py before.txt after.txt [--tol 1e-6]
# SCRIPT_VERSION: 2026-10-24.1
import argparse, sys

ap = argparse.ArgumentParser(); ap.add_argument('before'); ap.add_argument('after'); ap.add_argument('--tol', type=float, default=1e-6)
a = ap.parse_args()

def sections(path):
    out, cur = {}, None
    for line in open(path, encoding='utf-8-sig').read().splitlines():
        if line.startswith('## '): cur = line[3:]; out[cur] = []
        elif cur is not None: out[cur].append(line)
    return out

def same(x, y):
    x, y = x.strip(), y.strip()
    try: fx, fy = float(x), float(y)
    except ValueError: return x == y
    return abs(fx - fy) <= a.tol * max(1.0, abs(fx))

b, c = sections(a.before), sections(a.after)
bad = []
for k in sorted(set(b) | set(c)):
    rb, rc = b.get(k), c.get(k)
    if rb is None or rc is None: bad.append((k, 'only in ' + ('after' if rb is None else 'before'))); continue
    if len(rb) != len(rc): bad.append((k, f'rows {len(rb)} -> {len(rc)}')); continue
    for lb, lc in zip(rb, rc):
        fb, fc = lb.split('|'), lc.split('|')
        if len(fb) != len(fc) or not all(same(x, y) for x, y in zip(fb, fc)):
            bad.append((k, f'{lb[:80]}  ->  {lc[:80]}')); break
print(f'sections: {len(b)} / {len(c)}  differing: {len(bad)}  (tolerance {a.tol})')
for k, why in bad[:40]: print(f'  {k}: {why}')
sys.exit(1 if bad else 0)
