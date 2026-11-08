r"""Model view: all cards collapsed; tables without relationships -> one column in the top-left corner, one under
another (_Measures first, then by name). Connected tables keep their places; if one overlaps the column, all connected
tables move right by the overlap. Edit only with the report CLOSED (Desktop writes its in-memory layout back on save).
Collapsing an expanded card: expandedHeight = its height, height = 72 (80 + 24 per related key field, which stay
visible); Desktop corrects the height on open. Cards already collapsed keep Desktop's height.
python -I -X utf8 StackDisconnectedTables.py <X.SemanticModel> [--apply]
Change log:
2026-10-28.2  All cards collapsed.
2026-10-28.1  Created (refactoring step: disconnected tables top-left).
"""
import glob, io, json, os, re, shutil, sys, time

SM = sys.argv[1]
APPLY = '--apply' in sys.argv
GAP, MARGIN = 20, 100

rel_file = os.path.join(SM, 'definition', 'relationships.tmdl')
rel = io.open(rel_file, encoding='utf-8').read() if os.path.exists(rel_file) else ''
keys = {(m.group(2), m.group(3)) for m in re.finditer(r"(?:fromColumn|toColumn):\s*('?)(.+?)\1\.'?([^'\r\n]+)'?", rel)}
linked = {t for t, _ in keys}

path = os.path.join(SM, 'diagramLayout.json')
d = json.load(io.open(path, encoding='utf-8'))
nodes = d['diagrams'][0]['nodes']
collapsed = 0
for n in nodes:
    if 'expandedHeight' in n: continue
    k = sum(1 for t, _ in keys if t == n['nodeIndex'])
    n['expandedHeight'] = n['size']['height']
    n['size']['height'] = 72 if k == 0 else 80 + 24 * k
    collapsed += 1
free = sorted((n for n in nodes if n['nodeIndex'] not in linked),
              key=lambda n: (n['nodeIndex'] != '_Measures', n['nodeIndex'].lower()))

y = 0
for n in free:
    n['location'] = {'x': 0, 'y': y}
    y += n['size']['height'] + GAP
col_w = max((n['size']['width'] for n in free), default=0)

rest = [n for n in nodes if n['nodeIndex'] in linked]
min_x = min((n['location']['x'] for n in rest), default=col_w + MARGIN)
shift = max(0, col_w + MARGIN - min_x)
for n in rest:
    n['location']['x'] += shift

print(f"collapsed now: {collapsed}; disconnected: {len(free)} -> x=0, y 0..{y - GAP:.0f}; connected: {len(rest)}, shifted right by {shift:.0f}")
for n in free:
    print(f"  {n['nodeIndex']:28} y={n['location']['y']:.0f}")
if APPLY:
    bk = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(SM))), 'BackUp',
                      'StackDisconnectedTables_' + time.strftime('%Y-%m-%d_%H%M%S'))
    os.makedirs(bk, exist_ok=True)
    shutil.copy2(path, bk)
    io.open(path, 'w', encoding='utf-8').write(json.dumps(d, indent=2, ensure_ascii=False))
    print('written; backup', bk)
else:
    print('dry run (--apply to write)')
