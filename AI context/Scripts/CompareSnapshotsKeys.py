"""Compare two SnapshotMeasures files on the keys both have (optionally only some keys); totals listed apart.
python -I -X utf8 CompareSnapshotsKeys.py before.txt after.txt [--keys 2023,2024,2025,2026] [--tol 1e-6]"""
import argparse, io, re

ap = argparse.ArgumentParser()
ap.add_argument('a'); ap.add_argument('b'); ap.add_argument('--keys', default=''); ap.add_argument('--tol', type=float, default=1e-6)
x = ap.parse_args()
keys = set(k for k in x.keys.split(',') if k)


def load(p):
    secs, cur = {}, None
    for line in io.open(p, encoding='utf-8-sig').read().splitlines():
        if line.startswith('## '):
            cur = line[3:].strip(); secs[cur] = {}
        elif cur is not None:
            if ' | ' in line:
                k, v = line.split(' | ', 1)
            else:
                k, v = '<total>', line
            secs[cur][k.strip()] = v.strip()
    return secs


def same(u, v):
    if u == v:
        return True
    try:
        fu, fv = float(u), float(v)
        return abs(fu - fv) <= x.tol * max(1.0, abs(fu), abs(fv))
    except ValueError:
        return False


A, B = load(x.a), load(x.b)
diff_tot, diff_rows = [], []
for s in sorted(set(A) & set(B)):
    for k in sorted(set(A[s]) & set(B[s])):
        if keys and k != '<total>' and k not in keys:
            continue
        if not same(A[s][k], B[s][k]):
            (diff_tot if k == '<total>' else diff_rows).append('%s [%s]: %s -> %s' % (s, k, A[s][k][:60], B[s][k][:60]))
    for k in sorted((set(A[s]) ^ set(B[s])) & (keys or set())):
        diff_rows.append('%s [%s]: only in %s' % (s, k, 'before' if k in A[s] else 'after'))
print('differences by key:', len(diff_rows)); print('\n'.join(diff_rows))
print('differences at total:', len(diff_tot)); print('\n'.join(diff_tot))
