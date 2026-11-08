"""Every slicer on a year (a column named Year, or a hierarchy whose first level is a Year column) sorted Descending.
Lists each year slicer with its current sort; --write sets sortDefinition to the year field, Descending, rewriting only
the "query" block (positions keep their digits). Keep CRLF: the file newline is preserved.
usage: python -X utf8 SetYearSlicersDescending.py <folder with X.SemanticModel and X.Report> [--write]
Then apply in Desktop (powerbi-desktop reload). ClientD Finance 2026-10-23: 13 of 17 fixed.
SCRIPT_VERSION: 2026-10-23.1
"""
import json, pathlib, re, sys

root = pathlib.Path(sys.argv[1])
write = '--write' in sys.argv
rep = next(root.glob('*.Report')) / 'definition'
tables = next(root.glob('*.SemanticModel')) / 'definition' / 'tables'

# hierarchies whose FIRST level is a Year column: (table, hierarchy) -> first level name
year_hier = {}
for t in tables.glob('*.tmdl'):
    txt = t.read_text(encoding='utf-8')
    for m in re.finditer(r'(?m)^\thierarchy (.+)\n((?:\t\t.*\n|\s*\n)*)', txt):
        lv = re.search(r'level (.+)\n(?:\t\t\t.*\n)*?\t\t\tcolumn: (.+)', m.group(2))
        if lv and lv.group(2).strip().strip("'") == 'Year':
            year_hier[(t.stem, m.group(1).strip().strip("'"))] = lv.group(1).strip().strip("'")

pages = {p.parent.name: json.loads(p.read_text(encoding='utf-8'))['displayName'] for p in rep.glob('pages/*/page.json')}


def year_field(f):
    c = f.get('Column')
    if c and c.get('Property') == 'Year':
        return True
    h = f.get('HierarchyLevel')
    if h:
        hh = h['Expression']['Hierarchy']
        key = (hh['Expression']['SourceRef'].get('Entity'), hh['Hierarchy'])
        return year_hier.get(key) == h['Level']
    return False


changed = 0
for f in sorted(rep.glob('pages/*/visuals/*/visual.json')):
    j = json.loads(f.read_text(encoding='utf-8'))
    v = j.get('visual', {})
    if v.get('visualType') not in ('slicer', 'advancedSlicerVisual'):
        continue
    projs = [p for r in v.get('query', {}).get('queryState', {}).values() for p in r.get('projections', [])]
    yp = [p for p in projs if year_field(p['field'])]
    if not yp:
        continue
    sd = v['query'].get('sortDefinition', {}).get('sort', [])
    cur = [(json.dumps(s['field'], ensure_ascii=False)[-60:], s.get('direction')) for s in sd]
    ok = len(sd) == 1 and sd[0]['field'] == yp[0]['field'] and sd[0].get('direction') == 'Descending'
    kind = 'hierarchy' if 'HierarchyLevel' in yp[0]['field'] else 'column'
    ent = (yp[0]['field'].get('Column') or yp[0]['field']['HierarchyLevel']['Expression']['Hierarchy'])['Expression']['SourceRef'].get('Entity')
    print(f"{'OK ' if ok else 'FIX'} {pages[f.parts[-4]]:<40} {f.parts[-2]} {kind:<9} {ent:<14} sort={[d for _, d in cur] or 'none'}")
    if not ok and write:
        v['query']['sortDefinition'] = {'sort': [{'field': yp[0]['field'], 'direction': 'Descending'}]}
        raw = f.read_bytes()
        nl = '\r\n' if b'\r\n' in raw else '\n'            # read_text() would turn CRLF into LF
        text = raw.decode('utf-8').replace('\r\n', '\n')
        # keep the file's formatting: replace only the text of the "query" block (positions keep their digits)
        start = text.index('\n    "query": {') + 1
        depth, i = 0, text.index('{', start)
        while True:
            depth += {'{': 1, '}': -1}.get(text[i], 0)
            if depth == 0:
                break
            i += 1
        block = '    "query": ' + json.dumps(v['query'], ensure_ascii=False, indent=2).replace('\n', '\n    ')
        new = text[:start] + block + text[i + 1:]
        if json.loads(new) != j:
            raise SystemExit(f'{f}: rebuilt file differs from the intended JSON')
        f.write_bytes(new.replace('\n', nl).encode('utf-8'))
        changed += 1
print('year hierarchies:', year_hier)
print('changed:', changed)
