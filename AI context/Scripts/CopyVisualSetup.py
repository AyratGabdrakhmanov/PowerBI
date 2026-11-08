# Copy the setup of one visual (the template) to other visuals in a PBIR report:
#   fields  - visual.query and the expansion-state levels (each target keeps its own expanded/selected "root")
#   measure - the template's visual-level measure filters (added / replaced by measure name; other filters stay)
#   size    - width and height
#   x       - horizontal position (y, z, tabOrder stay)
# Usage:
#   python -I CopyVisualSetup.py <X.Report> --template Page7/slicer57 --targets slicer88,slicer94 [--parts fields,measure,size,x] [--apply]
# Default parts: all four. Default: dry run. --apply makes a backup (nearest "BackUp" folder above the report,
# CopyVisualSetup_<timestamp>) and keeps CRLF / trailing newline. After --apply: powerbi-desktop status -> reload
# (on a real report ask the user first). Companion of ReportFields.py.
#
# SCRIPT_VERSION: 2026-10-15.1
import argparse, copy, glob, json, os, shutil, sys
from datetime import datetime

sys.stdout.reconfigure(encoding='utf-8')
ap = argparse.ArgumentParser()
ap.add_argument('report')
ap.add_argument('--template', required=True)
ap.add_argument('--targets', required=True)
ap.add_argument('--parts', default='fields,measure,size,x')
ap.add_argument('--apply', action='store_true')
a = ap.parse_args()

report = os.path.abspath(a.report.rstrip('\\/'))
pages = os.path.join(report, 'definition', 'pages')
parts = set(a.parts.split(','))


def find(name):
    hits = glob.glob(os.path.join(pages, name, 'visual.json')) if '/' in name else \
        glob.glob(os.path.join(pages, '*', 'visuals', name, 'visual.json'))
    if '/' in name and not hits:
        pg, vn = name.split('/')
        hits = glob.glob(os.path.join(pages, pg, 'visuals', vn, 'visual.json'))
    if len(hits) != 1:
        sys.exit(f'Visual "{name}": {len(hits)} match(es) - use Page/visual')
    return hits[0]


def load(p):
    raw = open(p, 'rb').read()
    return raw, json.loads(raw.decode('utf-8-sig'))


def dump(raw, j):
    s = json.dumps(j, ensure_ascii=False, indent=2).encode('utf-8')
    nl = b'\r\n' if b'\r\n' in raw else b'\n'
    s = s.replace(b'\n', nl)
    return (b'\xef\xbb\xbf' if raw.startswith(b'\xef\xbb\xbf') else b'') + s + (nl if raw.endswith(nl) else b'')


_, t = load(find(a.template))
tv = t['visual']
t_measures = [f for f in t.get('filterConfig', {}).get('filters', []) if 'Measure' in f.get('field', {})]

changes = {}
for name in a.targets.split(','):
    p = find(name.strip())
    raw, j = load(p)
    v = j['visual']
    if v.get('visualType') != tv.get('visualType'):
        print(f'  !! {name}: {v.get("visualType")} vs template {tv.get("visualType")} - skipped')
        continue
    done = []
    if 'fields' in parts:
        v['query'] = copy.deepcopy(tv['query'])
        if 'expansionStates' in tv:
            roots = {tuple(e.get('roles', [])): e.get('root') for e in v.get('expansionStates', []) if e.get('root')}
            v['expansionStates'] = copy.deepcopy(tv['expansionStates'])
            for e in v['expansionStates']:
                e.pop('root', None)
                if roots.get(tuple(e.get('roles', []))):
                    e['root'] = roots[tuple(e.get('roles', []))]
        else:
            v.pop('expansionStates', None)
        # the field-well filter cards follow the fields; filters with a condition stay
        fl = j.setdefault('filterConfig', {}).setdefault('filters', [])
        fl[:] = [f for f in fl if 'filter' in f or 'Measure' in f.get('field', {})] + \
                [copy.deepcopy(f) for f in t.get('filterConfig', {}).get('filters', [])
                 if 'filter' not in f and 'Measure' not in f.get('field', {})]
        done.append('fields')
    if 'measure' in parts and t_measures:
        fl = j.setdefault('filterConfig', {}).setdefault('filters', [])
        names = {f['field']['Measure']['Property'] for f in t_measures}
        fl[:] = [f for f in fl if f.get('field', {}).get('Measure', {}).get('Property') not in names] + \
                [copy.deepcopy(f) for f in t_measures]
        done.append('measure: ' + ', '.join(sorted(names)))
    pos, tp = j['position'], t['position']
    if 'size' in parts:
        done.append(f"size {pos['width']:.0f}x{pos['height']:.0f} -> {tp['width']:.0f}x{tp['height']:.0f}")
        pos['width'], pos['height'] = tp['width'], tp['height']
    if 'x' in parts:
        done.append(f"x {pos['x']:.0f} -> {tp['x']:.0f}")
        pos['x'] = tp['x']
    new = dump(raw, j)
    if new != raw:
        changes[p] = new
    print(f"  {os.path.relpath(p, pages)}: {'; '.join(done)}")

print(f'TOTAL files to change: {len(changes)}  ({"APPLY" if a.apply else "dry run"})')
if a.apply and changes:
    up, bdir = os.path.dirname(report), None
    for _ in range(3):
        if os.path.isdir(os.path.join(up, 'BackUp')):
            bdir = os.path.join(up, 'BackUp')
            break
        up = os.path.dirname(up)
    dest = os.path.join(bdir or os.path.join(os.path.dirname(report), 'BackUp'),
                        f'CopyVisualSetup_{datetime.now():%Y-%m-%d_%H%M%S}')
    shutil.copytree(report, os.path.join(dest, os.path.basename(report)))
    print(f'Backup: {dest}')
    for p, data in changes.items():
        open(p, 'wb').write(data)
