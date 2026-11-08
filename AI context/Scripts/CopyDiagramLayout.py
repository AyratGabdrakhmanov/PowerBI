# Copy the Model view layout (table boxes: position, size, z-order, expanded height) from one PBIP
# semantic model to another - e.g. from an archive copy whose diagram was arranged nicely.
# File: <X>.SemanticModel\diagramLayout.json. Diagrams (tabs "All tables", "Layout 1", ...) are matched
# by name; tables by name, then by lineageTag (from the diagram node, or - when the node has none,
# as Desktop often writes it - from the target model's tables\*.tmdl), so renamed tables still match.
# Target tables that are not in the source diagram are placed in a grid below the copied ones.
#
# Usage:
#   python -I CopyDiagramLayout.py <source.SemanticModel> <target.SemanticModel>            # dry run
#   python -I CopyDiagramLayout.py <source.SemanticModel> <target.SemanticModel> --apply    # write (backup first)
# Options: --diagram "All tables" (only this tab), --view (also copy zoom / scroll position)
# Backup: nearest "BackUp" folder above the target -> CopyDiagramLayout_<timestamp>\diagramLayout.json
# Power BI Desktop keeps the diagram in memory and writes it back on Ctrl+S: apply while the target
# file is closed, or reopen it without saving - check before writing to a file open in Desktop.
#
# SCRIPT_VERSION: 2026-10-15.1
import argparse, glob, json, os, re, shutil, sys
from datetime import datetime

sys.stdout.reconfigure(encoding='utf-8')
ap = argparse.ArgumentParser()
ap.add_argument('source')
ap.add_argument('target')
ap.add_argument('--apply', action='store_true')
ap.add_argument('--diagram')
ap.add_argument('--view', action='store_true')
a = ap.parse_args()


def layout_path(p):
    p = os.path.abspath(p.rstrip('\\/'))
    return p if p.endswith('.json') else os.path.join(p, 'diagramLayout.json')


src_path, dst_path = layout_path(a.source), layout_path(a.target)
for p in (src_path, dst_path):
    if not os.path.exists(p):
        sys.exit(f'Not found: {p}')
src = json.load(open(src_path, encoding='utf-8-sig'))
raw = open(dst_path, 'rb').read()
dst = json.loads(raw.decode('utf-8-sig'))

# table name -> lineageTag from the target model's TMDL (fills nodes without nodeLineageTag)
model_tags = {}
for t in glob.glob(os.path.join(os.path.dirname(dst_path), 'definition', 'tables', '*.tmdl')):
    txt = open(t, encoding='utf-8-sig').read()
    m = re.match(r"\s*table\s+(?:'((?:[^']|'')+)'|(\S+))", txt)
    tag = re.search(r'^\tlineageTag:\s*(\S+)', txt, re.M)
    if m and tag:
        model_tags[(m.group(1) or m.group(2)).replace("''", "'")] = tag.group(1)

COPY = ('location', 'size', 'zIndex', 'expandedHeight')
src_diagrams = {d.get('name'): d for d in src.get('diagrams', [])}
changed = False
for d in dst.get('diagrams', []):
    name = d.get('name')
    if a.diagram and name != a.diagram:
        continue
    s = src_diagrams.get(name)
    if not s:
        print(f'[{name}] not in source - left as is')
        continue
    by_name = {n['nodeIndex']: n for n in s.get('nodes', [])}
    by_tag = {n['nodeLineageTag']: n for n in s.get('nodes', []) if n.get('nodeLineageTag')}
    matched, renamed, new = [], [], []
    used = set()
    for n in d.get('nodes', []):
        sn = by_name.get(n['nodeIndex'])
        if sn is None:
            tag = n.get('nodeLineageTag') or model_tags.get(n['nodeIndex'])
            sn = by_tag.get(tag)
            if sn is not None:
                renamed.append(f"{sn['nodeIndex']} -> {n['nodeIndex']}")
        if sn is None:
            new.append(n)
            continue
        used.add(sn['nodeIndex'])
        for k in COPY:
            if k in sn and n.get(k) != sn[k]:
                n[k] = json.loads(json.dumps(sn[k])); changed = True
        matched.append(n)
    # tables not in the source: a grid under the copied boxes
    if new and matched:
        bottom = max(n['location']['y'] + n.get('size', {}).get('height', 72) for n in matched)
        left = min(n['location']['x'] for n in matched)
        for i, n in enumerate(new):
            loc = {'x': left + (i % 6) * 260, 'y': bottom + 80 + (i // 6) * 200}
            if n.get('location') != loc:
                n['location'] = loc; changed = True
    if a.view:
        for k in ('zoomValue', 'scrollPosition'):
            if k in s and d.get(k) != s[k]:
                d[k] = s[k]; changed = True
    gone = sorted(set(by_name) - used)
    print(f'[{name}] copied {len(matched)} table(s)' + (f'; matched by lineageTag (renamed): {", ".join(renamed)}' if renamed else ''))
    if new:
        print(f'   not in source, placed in a grid below: {", ".join(n["nodeIndex"] for n in new)}')
    if gone:
        print(f'   in source only (deleted / not in target): {", ".join(gone)}')

if not changed:
    print('Nothing to change.')
    sys.exit(0)
print('APPLY' if a.apply else 'dry run - nothing written (add --apply)')
if not a.apply:
    sys.exit(0)

up, bdir = os.path.dirname(dst_path), None
for _ in range(4):
    if os.path.isdir(os.path.join(up, 'BackUp')):
        bdir = os.path.join(up, 'BackUp')
        break
    up = os.path.dirname(up)
dest = os.path.join(bdir or os.path.join(os.path.dirname(dst_path), 'BackUp'), f'CopyDiagramLayout_{datetime.now():%Y-%m-%d_%H%M%S}')
os.makedirs(dest, exist_ok=True)
shutil.copy2(dst_path, dest)
print(f'Backup: {dest}')
nl = b'\r\n' if b'\r\n' in raw else b'\n'
out = json.dumps(dst, ensure_ascii=False, indent=2).encode('utf-8').replace(b'\n', nl) + (nl if raw.endswith(nl) else b'')
open(dst_path, 'wb').write((b'\xef\xbb\xbf' if raw.startswith(b'\xef\xbb\xbf') else b'') + out)
print(f'Written: {dst_path}')
