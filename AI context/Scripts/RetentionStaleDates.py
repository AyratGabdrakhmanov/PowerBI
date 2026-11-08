r"""Retention (Refactoring.md step 12): saved report selections older than the window -> moved into it. Closed PBIP only.
Window = current year - YEARS_BACK .. (reference Calendar). Dry run by default; --apply writes the changed files
(backup of each one first: <backup dir>\<path inside X.Report>).
  python -I -X utf8 RetentionStaleDates.py "<X.Report>" "<backup dir>" [--apply]
1. Date-range slicers (visual.json objects): on a page with a stale slicer, the date slicers saved before the current year
   (period A / B pairs) move together by whole years - to the latest year in which every selected month has started.
2. Page filters on Calendar[Year] (In, one year) + optional [Month Name] (In / Not In): same shift.
   Calendar[Year] Not In (exclusion): the stale years are dropped from the list (no visible change).
3. Bookmark slicer states with a stale date get the visual's saved state (after 1).
Anything else stale is listed as UNHANDLED and left as is.
Change log:
2026-11-01.1  Created (retention policy current year + 2 full years back, ClientB + ClientC).
"""
import datetime, json, os, re, shutil, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'Refactoring', 'ClientC'))
import jsonrt

YEARS_BACK = 2
REP, BACKUP = sys.argv[1], sys.argv[2]; APPLY = '--apply' in sys.argv; D = os.path.join(REP, 'definition')
TODAY = datetime.date.today(); MIN_YEAR = TODAY.year - YEARS_BACK
RX_DT = re.compile(r"datetime'(\d{4})-(\d\d)-(\d\d)T")
RX_Y = re.compile(r"^(\d{4})L$")
files, changes, unhandled = {}, [], []


def load(p):
    if p not in files:
        t = jsonrt.read(p); files[p] = [t, jsonrt.load(t)]
    return files[p][1]


def dates(o):
    return [datetime.date(int(y), int(m), int(d)) for y, m, d in RX_DT.findall(json.dumps(o))]


def is_stale(o):
    s = json.dumps(o)
    return any(int(y) < MIN_YEAR for y, _, _ in RX_DT.findall(s)) or \
        any(int(y) < MIN_YEAR for y in re.findall(r'"Value": "(\d{4})L"', s))


def delta_for(last_year, last_month):
    return TODAY.year - last_year - (1 if last_month > TODAY.month else 0)


def shift(o, n):
    """Every datetime / year literal in o moved by n years (in place)."""
    def mv(v):
        m = RX_Y.match(v)
        if m:
            return '%dL' % (int(m.group(1)) + n)
        def r(mm):
            y, mo, d = int(mm.group(1)) + n, mm.group(2), mm.group(3)
            if mo == '02' and d == '29': d = '28'
            return "datetime'%04d-%s-%sT" % (y, mo, d)
        return RX_DT.sub(r, v)
    if isinstance(o, dict):
        for k, v in o.items():
            if k == 'Value' and isinstance(v, str): o[k] = mv(v)
            else: shift(v, n)
    elif isinstance(o, list):
        for v in o: shift(v, n)


def last_selected(ds):
    """Range slicer: [start, end) - the last selected day is end - 1."""
    return max(ds) - datetime.timedelta(days=1) if len(ds) >= 2 else max(ds)


# 1. date-range slicers
pages = sorted(os.listdir(os.path.join(D, 'pages')))
pages = [p for p in pages if os.path.isdir(os.path.join(D, 'pages', p))]
visuals = {}
for pg in pages:
    vd = os.path.join(D, 'pages', pg, 'visuals')
    if not os.path.isdir(vd): continue
    for vn in os.listdir(vd):
        visuals[(pg, vn)] = os.path.join(vd, vn, 'visual.json')
for pg in pages:
    group = []
    for (p, vn), path in visuals.items():
        if p != pg: continue
        o = load(path); objs = o.get('visual', {}).get('objects', {})
        ds = dates(objs)
        if o.get('visual', {}).get('visualType') == 'slicer' and ds and max(ds).year < TODAY.year:
            group.append((vn, path, objs, ds))
        elif is_stale(o):
            unhandled.append('%s/%s visual' % (pg, vn))
    if not any(min(g[3]).year < MIN_YEAR for g in group): continue
    last = max(last_selected(g[3]) for g in group); n = delta_for(last.year, last.month)
    for vn, path, objs, ds in group:
        before = sorted(set(d.isoformat() for d in ds)); shift(objs, n)
        changes.append((path, '%s/%s slicer %s -> +%d years' % (pg, vn, before, n)))

# 2. page filters
for pg in pages:
    path = os.path.join(D, 'pages', pg, 'page.json'); o = load(path)
    fl = o.get('filterConfig', {}).get('filters', [])
    if not is_stale(fl): continue
    by = {f.get('field', {}).get('Column', {}).get('Property'): f for f in fl if f.get('filter')}
    yf = by.get('Year')
    stale_other = [k for k, f in by.items() if k not in ('Year', 'Month Name') and is_stale(f)]
    if not yf or stale_other:
        unhandled.append('%s page filters %s' % (pg, stale_other or 'no Year filter')); continue
    cond = yf['filter']['Where'][0]['Condition']
    if 'Not' in cond:
        vals = cond['Not']['Expression']['In']['Values']
        keep = [v for v in vals if not (RX_Y.match(v[0]['Literal']['Value']) and int(v[0]['Literal']['Value'][:4]) < MIN_YEAR)]
        cond['Not']['Expression']['In']['Values'] = keep
        changes.append((path, '%s Year Not In: %d stale years dropped' % (pg, len(vals) - len(keep))))
        continue
    yv = [v[0]['Literal']['Value'] for v in cond['In']['Values']]
    if len(yv) != 1:
        unhandled.append('%s Year In %s' % (pg, yv)); continue
    y0 = int(yv[0][:4]); months = set(range(1, 13)); mf = by.get('Month Name')
    if mf:
        mc = mf['filter']['Where'][0]['Condition']
        neg = 'Not' in mc; inn = mc['Not']['Expression']['In'] if neg else mc['In']
        ms = {d.month for d in dates(inn['Values'])}
        months = months - ms if neg else ms
    n = delta_for(y0, max(months))
    shift(yf['filter'], n)
    if mf: shift(mf['filter'], n)
    changes.append((path, '%s Year %d -> %d, months %s%s' % (pg, y0, y0 + n, sorted(months), ' (Month Name shifted)' if mf else '')))

# 3. bookmarks
bd = os.path.join(D, 'bookmarks')
for f in sorted(os.listdir(bd)) if os.path.isdir(bd) else []:
    if not f.endswith('.bookmark.json'): continue
    path = os.path.join(bd, f); o = load(path)
    for pg, sec in o.get('explorationState', {}).get('sections', {}).items():
        for vn, vc in sec.get('visualContainers', {}).items():
            merge = vc.get('singleVisual', {}).get('objects', {}).get('merge', {})
            if not is_stale(merge): continue
            vpath = visuals.get((pg, vn))
            if not vpath:
                unhandled.append('%s %s/%s (visual not found)' % (f, pg, vn)); continue
            vobjs = load(vpath).get('visual', {}).get('objects', {})
            for key in ('general', 'data'):
                if key not in merge or not is_stale(merge[key]): continue
                props = merge[key][0].setdefault('properties', {})
                vprops = (vobjs.get(key) or [{}])[0].get('properties', {})
                for pk in [k for k in props if is_stale(props[k])]:
                    if pk in vprops: props[pk] = json.loads(json.dumps(vprops[pk]))
                    else: del props[pk]
            changes.append((path, '%s %s %s/%s -> visual saved state %s' % (f, o.get('displayName', ''), pg, vn,
                                                                            sorted(set(d.isoformat() for d in dates(vobjs))))))

for path, what in changes: print('  ', what)
for u in unhandled: print('   UNHANDLED', u)
left = [p for p, (t, o) in files.items() if is_stale(o)]
print('changes %d, unhandled %d, files still stale after fix %d' % (len(changes), len(unhandled), len(left)))
if APPLY:
    for p in sorted(set(p for p, _ in changes)):
        b = os.path.join(BACKUP, os.path.relpath(p, REP)); os.makedirs(os.path.dirname(b), exist_ok=True)
        shutil.copy2(p, b); jsonrt.write(p, jsonrt.dump(files[p][1], files[p][0]))
    print('written', len(set(p for p, _ in changes)), 'files; backup', BACKUP)
