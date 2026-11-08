r"""Check that tooltip text fits its tooltip page (refactoring step 24, user 2026-10-30).
Screenshots every tooltip page (page.json "type": "Tooltip") of the report open in Desktop via the powerbi-desktop bridge,
finds the filled box and the light text inside it, and flags a page when the text comes closer than MARGIN of the box
size to an edge (cut lines, "..." at the end). Prints a summary only. Run once per language (switch the Language filter /
reload with the other default), because the text length differs.

python -X utf8 CheckTooltipFit.py "<X.Report>" [--out <png folder>] [--pid <Desktop pid>] [--fill RRGGBB]

Change log:
2026-10-30.1  Created (ClientB Inventory Coverage).
"""
import json, pathlib, subprocess, sys, tempfile
from PIL import Image

MARGIN = 0.02          # text must keep at least 2 % of the box width / height from each edge
FILL = (0x13, 0x45, 0x91)   # tooltip box colour ([Blue Logo]); pass --fill RRGGBB for another report
TOL = 30
if '--fill' in sys.argv:
    hx = sys.argv[sys.argv.index('--fill') + 1].lstrip('#'); FILL = tuple(int(hx[i:i + 2], 16) for i in (0, 2, 4))
rep = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[sys.argv.index('--out') + 1]) if '--out' in sys.argv else pathlib.Path(tempfile.mkdtemp(prefix='ttfit_'))
pid = ['--pid', sys.argv[sys.argv.index('--pid') + 1]] if '--pid' in sys.argv else []
out.mkdir(parents=True, exist_ok=True)

pages = []
for pj in sorted((rep / 'definition' / 'pages').glob('*/page.json')):
    p = json.loads(pj.read_text(encoding='utf-8'))
    if p.get('type') == 'Tooltip':
        pages.append((pj.parent.name, p.get('displayName', '')))

def lum(px): return 0.299 * px[0] + 0.587 * px[1] + 0.114 * px[2]

bad = 0
for pid_, name in pages:
    png = out / f'{pid_}.png'
    r = subprocess.run(['powerbi-desktop', 'screenshot', pid_, '--output', str(png), *pid], capture_output=True, text=True, shell=True)
    if not png.exists():
        print(f'ERROR   {pid_:28} {name}: no screenshot'); bad += 1; continue
    im = Image.open(png).convert('RGB'); w, h = im.size; px = im.load()
    # box = pixels of the tooltip fill colour (FILL, the [Blue Logo] measure); text = light pixels inside it
    step = 2
    isfill = lambda c: all(abs(c[i] - FILL[i]) <= TOL for i in range(3))
    # the box = rows / columns where the fill colour dominates (stray blue icons and banners do not count)
    rows = [y for y in range(0, h, step) if sum(isfill(px[x, y]) for x in range(0, w, step)) > 0.25 * w / step]
    if not rows:
        print(f'NO BOX  {pid_:28} {name}'); bad += 1; continue
    y0, y1 = rows[0], rows[-1]
    cols = [x for x in range(0, w, step) if sum(isfill(px[x, y]) for y in range(y0, y1, step)) > 0.5 * (y1 - y0) / step]
    box = [cols[0], y0, cols[-1], y1] if cols else [0, 0, 0, 0]
    if box[2] <= box[0]:
        print(f'NO BOX  {pid_:28} {name}'); bad += 1; continue
    txt = [w, h, 0, 0]
    for y in range(box[1], box[3], step):
        for x in range(box[0], box[2], step):
            if lum(px[x, y]) > 200:
                txt = [min(txt[0], x), min(txt[1], y), max(txt[2], x), max(txt[3], y)]
    bw, bh = box[2] - box[0], box[3] - box[1]
    if txt[2] <= txt[0]:
        print(f'EMPTY   {pid_:28} {name}'); continue
    gaps = {'left': (txt[0] - box[0]) / bw, 'right': (box[2] - txt[2]) / bw, 'top': (txt[1] - box[1]) / bh, 'bottom': (box[3] - txt[3]) / bh}
    tight = [k for k, g in gaps.items() if g < MARGIN]
    status = 'OVERFLOW' if tight else 'ok'
    bad += bool(tight)
    print(f'{status:8}{pid_:28} {name}' + (f'  (touches: {", ".join(tight)})' if tight else ''))
print(f'tooltip pages: {len(pages)}, problems: {bad}; screenshots: {out}')
