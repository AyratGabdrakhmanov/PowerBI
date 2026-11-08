r"""Check the position of every info icon (step 24: 20x20 button slicer on CT_BlankTable[Info]) against its table / matrix:
y = visual y + 27 (title on) or + 1 (title off); x = visual x + 10 + cumulative column widths (first columnWidth entry per
column, Desktop uses the first) - 8, i.e. the top-right corner of a column header. Prints off-rule icons + a summary.
Usage: python CheckInfoIcons.py "<X.Report>" [--tol 3] [--fix]   (--fix: snap icons within 10 px x / 15 px y to the rule)

Change log
2026-11-05  title counts as on only when set on (table / matrix default is off); --fix snaps icons to the rule
2026-11-05  first version (user: check all info icon positions)
"""
import json, os, sys, glob, collections
rep = os.path.join(sys.argv[1], 'definition')
tol = float(sys.argv[sys.argv.index('--tol') + 1]) if '--tol' in sys.argv else 3
HOSTS = ('tableEx', 'pivotTable')
bad, ok, orphan = [], 0, []
FIX = '--fix' in sys.argv; fixed = []
for pdir in sorted(glob.glob(os.path.join(rep, 'pages', '*'))):
    if not os.path.isdir(pdir): continue
    files = glob.glob(os.path.join(pdir, 'visuals', '*', 'visual.json'))
    vs = [json.load(open(f, encoding='utf-8')) for f in files]
    path_of = {v['name']: f for v, f in zip(vs, files)}
    icons = [v for v in vs if v.get('visual', {}).get('visualType') == 'advancedSlicerVisual'
             and 'CT_BlankTable' in json.dumps(v['visual'].get('query', {})) and v['position']['width'] <= 25
             and v['position']['x'] < 1250]   # the data-freshness ⓘ (x 1260) is checked by step 43
    hosts = [v for v in vs if v.get('visual', {}).get('visualType') in HOSTS and not v.get('isHidden')]
    page = json.load(open(os.path.join(pdir, 'page.json'), encoding='utf-8'))['displayName']
    for ic in icons:
        p = ic['position']
        h = [t for t in hosts if t['position']['x'] - 5 <= p['x'] <= t['position']['x'] + t['position']['width'] + 5
             and t['position']['y'] - 5 <= p['y'] <= t['position']['y'] + 70]
        if not h:
            orphan.append((page, ic['name'], round(p['x']), round(p['y']))); continue
        t = min(h, key=lambda t: abs(p['y'] - t['position']['y']))
        tp = t['position']; vis = t['visual']
        tshow = json.dumps(vis.get('visualContainerObjects', {}).get('title', [{}])[0].get('properties', {}).get('show', {}))
        title_on = 'true' in tshow   # tables / matrices: title is off unless set on
        ey = tp['y'] + (27 if title_on else 1)
        widths = collections.OrderedDict()
        for e in vis.get('objects', {}).get('columnWidth', []):
            m = (e.get('selector') or {}).get('metadata')
            if m and m not in widths:
                widths[m] = e['properties'].get('value', {}).get('expr', {}).get('Literal', {}).get('Value', '0D')
        order = [x.get('queryRef') for r in vis.get('query', {}).get('queryState', {}).values() for x in r.get('projections', [])]
        cum, cands = 0.0, []
        for q in order:
            if q in widths:
                cum += float(str(widths[q]).rstrip('DL')); cands.append(tp['x'] + 10 + cum - 8)
        best = min(cands, key=lambda c: abs(p['x'] - c), default=None)
        dx = abs(p['x'] - best) if best is not None else None
        dy = p['y'] - ey
        if dx is None or dx > tol or abs(dy) > tol:
            if FIX and dx is not None and dx <= 10 and abs(dy) <= 15:
                ic['position']['x'], ic['position']['y'] = best, ey
                json.dump(ic, open(path_of[ic['name']], 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
                fixed.append(ic['name']); continue
            bad.append((page, t['name'], ic['name'], round(p['x']), round(p['y']), 'dx %s' % (round(dx, 1) if dx is not None else 'no widths'), 'dy %s' % round(dy, 1), 'title on' if title_on else 'title off'))
        else:
            ok += 1
for b in bad: print('OFF', b)
for o in orphan: print('NO TABLE UNDER', o)
print('fixed:', len(fixed)) if FIX else None
print(f'icons ok: {ok} | off rule: {len(bad)} | without a table: {len(orphan)}')
