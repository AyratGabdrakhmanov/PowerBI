"""Which visuals depend on some tables - directly (column / hierarchy level / measure hosted there) or through a
measure whose DAX (transitively) references them. Report only, nothing is changed.

usage: python -X utf8 TableUsage.py <folder with X.SemanticModel and X.Report> --tables "A,B" [--fields "x,y"] [--pages]
  --fields  only visuals using a field / measure whose printed name contains one of these strings
  --pages   summary per page instead of per visual
Before dropping or replacing a table (ClientD Finance 2026-10-23: JournalEntries and the Dim_*DynamicHierarchy tables).
Measures are matched by bracket name (measure names are model-wide unique); DAX comments are not stripped (over-reports).
SCRIPT_VERSION: 2026-10-23.1
"""
import argparse, collections, json, pathlib, re, sys

ap = argparse.ArgumentParser()
ap.add_argument('root'); ap.add_argument('--tables', required=True); ap.add_argument('--fields'); ap.add_argument('--pages', action='store_true')
a = ap.parse_args()
root = pathlib.Path(a.root)
sm, rp = next(root.glob('*.SemanticModel'), None), next(root.glob('*.Report'), None)
if not sm or not rp:
    sys.exit(f'Expected X.SemanticModel and X.Report under {root}')
TARGET = {t.strip() for t in a.tables.split(',')}
focus = [f.strip() for f in a.fields.split(',')] if a.fields else None

meas = {}
for f in (sm / 'definition' / 'tables').glob('*.tmdl'):
    t = f.read_text(encoding='utf-8-sig')
    tbl = re.search(r"(?m)^table (.+)$", t).group(1).strip().strip("'").replace("''", "'")
    for m in re.finditer(r"(?ms)^\tmeasure ('(?:[^']|'')+'|[^\s=]+)\s*=(.*?)(?=^\t\S|\Z)", t):
        meas[m.group(1).strip("'").replace("''", "'")] = (tbl, m.group(2))
direct = {n: {x for x in TARGET if re.search(r"'?" + re.escape(x) + r"'?\[", e)} | ({tb} & TARGET) for n, (tb, e) in meas.items()}
refs = {n: set(re.findall(r"(?<![\w'\]])\[([^\[\]]+)\]", e)) & set(meas) for n, (tb, e) in meas.items()}
dep = {}


def deps(n, stack=()):
    if n not in dep:
        out = set(direct.get(n, ()))
        for r in refs.get(n, ()):
            if r not in stack:
                out |= deps(r, stack + (n,))
        dep[n] = out
    return dep[n]


for n in meas:
    deps(n)

pages = {p.parent.name: json.loads(p.read_text(encoding='utf-8-sig')) for p in (rp / 'definition').glob('pages/*/page.json')}
rows = []
for v in (rp / 'definition').glob('pages/*/visuals/*/visual.json'):
    j = json.loads(v.read_text(encoding='utf-8-sig'))
    hits = collections.OrderedDict()

    def walk(o, al):
        if isinstance(o, dict):
            if isinstance(o.get('From'), list):
                al = {**al, **{x.get('Name'): x.get('Entity') for x in o['From'] if isinstance(x, dict)}}
            for k in ('Column', 'Measure', 'HierarchyLevel'):
                c = o.get(k)
                if not isinstance(c, dict):
                    continue
                if k == 'HierarchyLevel':
                    h = c.get('Expression', {}).get('Hierarchy', {}); sr = h.get('Expression', {}).get('SourceRef', {})
                    e = sr.get('Entity') or al.get(sr.get('Source'))
                    if e in TARGET:
                        hits[f"{e}.{h.get('Hierarchy')}.{c.get('Level')}"] = 'level'
                elif 'Property' in c:
                    sr = c.get('Expression', {}).get('SourceRef', {}); e = sr.get('Entity') or al.get(sr.get('Source'))
                    p = c['Property']
                    if k == 'Measure' and dep.get(p):
                        hits[f'[{p}]'] = 'measure -> ' + ', '.join(sorted(dep[p]))
                    elif e in TARGET:
                        hits[f'{e}[{p}]'] = k.lower()
            for x in o.values():
                walk(x, al)
        elif isinstance(o, list):
            for x in o:
                walk(x, al)

    walk(j, {})
    if not hits or (focus and not any(any(f in h for f in focus) for h in hits)):
        continue
    pg = pages.get(v.parts[-4], {})
    rows.append((pg.get('displayName', v.parts[-4]) + (' [hidden page]' if pg.get('visibility') == 'HiddenInViewMode' else ''),
                 j.get('visual', {}).get('visualType', 'group') + (' (hidden)' if j.get('isHidden') else ''), v.parts[-2], hits))

if a.pages:
    c = collections.Counter(r[0] for r in rows)
    for pg, n in sorted(c.items()):
        print(f'{pg:<50} {n} visual(s)')
else:
    for pg, vt, name, hits in sorted(rows):
        print(f'{pg} | {vt} | {name}')
        for h, k in hits.items():
            print(f'      {h}  ({k})')
print(f'TOTAL visuals: {len(rows)}')
