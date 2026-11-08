r"""Model view layout of a PBIP semantic model (refactoring step 13), main tab (the first diagram):
- every card collapsed;
- tables without relationships -> one column top-left (_Measures / Measure first, then by name);
- connected tables top-down, right of that column: row 1 = dimensions (only on the one side of relationships),
  row 2 = tables on both sides, row 3 = facts (only on the many side); each dimension is placed above the tables it
  is linked to (average position), so relationship lines run top -> down with fewer crossings;
- zoom = fit the whole layout (no Fit to page click needed), scroll to the top-left corner.
--remove-tabs also deletes every other Model view tab (only the main one stays, selected and default).
Edit only with the report CLOSED: Desktop holds the layout in memory and writes it back on save.
A table renamed via TOM keeps its old nodeIndex - rename the node first.
python -I -X utf8 ArrangeModelView.py <X.SemanticModel> [--remove-tabs] [--apply]      (dry run without --apply)
Change log:
2026-11-07.1  Created (ClientA Semantic Model): disconnected column + dimensions / both / facts rows, fit zoom, --remove-tabs.
"""
import io, json, os, re, shutil, sys, time
sys.stdout.reconfigure(encoding='utf-8')
SM = sys.argv[1]; APPLY = '--apply' in sys.argv; REMOVE_TABS = '--remove-tabs' in sys.argv
GAP_X, GAP_Y, COL_GAP, STACK_GAP = 40, 140, 160, 20
VIEW_W, VIEW_H = 1300, 760                       # visible canvas at 100% (px) for the fit zoom

rel_file = os.path.join(SM, 'definition', 'relationships.tmdl')
rel = io.open(rel_file, encoding='utf-8').read() if os.path.exists(rel_file) else ''
def tbl(s):
    s = s.strip()
    return (re.match(r"^'([^']+)'\.", s) or re.match(r"^([^.']+)\.", s)).group(1)
pairs = []
for b in rel.split('\nrelationship ')[1:]:
    pairs.append((tbl(re.search(r'fromColumn:\s*(.+)', b).group(1)), tbl(re.search(r'toColumn:\s*(.+)', b).group(1))))
many = {f for f, _ in pairs}; one = {t for _, t in pairs}
keys = {}
for f, t in pairs:
    keys[f] = keys.get(f, 0) + 1; keys[t] = keys.get(t, 0) + 1

path = os.path.join(SM, 'diagramLayout.json')
raw = io.open(path, encoding='utf-8').read()
d = json.loads(raw)
main = d['diagrams'][0]
removed = []
if REMOVE_TABS:
    removed = [g['name'] for g in d['diagrams'][1:]]
    d['diagrams'] = [main]
    d['selectedDiagram'] = main['name']; d['defaultDiagram'] = main['name']
nodes = main['nodes']
names = {n['nodeIndex'] for n in nodes}
collapsed = 0
for n in nodes:
    if 'expandedHeight' not in n:
        n['expandedHeight'] = n['size']['height']
        k = keys.get(n['nodeIndex'], 0)
        n['size']['height'] = 72 if k == 0 else 80 + 24 * k          # Desktop corrects the height on open
        collapsed += 1
free = sorted((n for n in nodes if n['nodeIndex'] not in many | one),
              key=lambda n: (n['nodeIndex'] not in ('_Measures', 'Measure'), n['nodeIndex'].lower()))
dims  = sorted((n for n in nodes if n['nodeIndex'] in one and n['nodeIndex'] not in many), key=lambda n: n['location']['x'])
mid   = sorted((n for n in nodes if n['nodeIndex'] in one and n['nodeIndex'] in many), key=lambda n: n['location']['x'])
facts = sorted((n for n in nodes if n['nodeIndex'] in many and n['nodeIndex'] not in one), key=lambda n: n['location']['x'])
order = {n['nodeIndex']: i for i, n in enumerate(mid + facts)}
def bary(n):
    nm = n['nodeIndex']
    xs = [order[o] for o in [f for f, t in pairs if t == nm] + [t for f, t in pairs if f == nm] if o in order]
    return sum(xs) / len(xs) if xs else 999
dims.sort(key=bary)

y = 0
for n in free:
    n['location'] = {'x': 0, 'y': y}; y += n['size']['height'] + STACK_GAP
x0 = (max(n['size']['width'] for n in free) + COL_GAP) if free else 0
y = 0
for row in (dims, mid, facts):
    if not row: continue
    x = x0
    for n in row:
        n['location'] = {'x': x, 'y': y}; x += n['size']['width'] + GAP_X
    y += max(n['size']['height'] for n in row) + GAP_Y
for i, n in enumerate(nodes): n['zIndex'] = i
W = max(n['location']['x'] + n['size']['width'] for n in nodes)
H = max(n['location']['y'] + n['size']['height'] for n in nodes)
main['zoomValue'] = round(min(VIEW_W / W, VIEW_H / H, 1) * 100, 2)
main['scrollPosition'] = {'x': 0, 'y': 0}

print(f'tabs removed: {len(removed)} {removed}' if REMOVE_TABS else f'tabs kept: {len(d["diagrams"])} (use --remove-tabs to keep only "{main["name"]}")')
print(f'cards collapsed now: {collapsed} | zoom {main["zoomValue"]}% for {round(W)} x {round(H)}')
for label, row in (('no relationships', free), ('dimensions', dims), ('both sides', mid), ('facts', facts)):
    print(f'{label} ({len(row)}): ' + ', '.join(n['nodeIndex'] for n in row))
missing = sorted(t for t in many | one if t not in names)
if missing: print('WARNING - related tables missing from the tab (renamed? add the node first):', missing)
if not APPLY:
    print('dry run - add --apply'); sys.exit(0)
bak = path + '.bak_' + time.strftime('%Y%m%d_%H%M%S')
shutil.copy2(path, bak)
nl = '\r\n' if '\r\n' in raw else '\n'
io.open(path, 'w', encoding='utf-8', newline='').write(json.dumps(d, indent=2, ensure_ascii=False).replace('\n', nl) + nl)
print('APPLIED, backup ' + os.path.basename(bak))
