# For every bookmark slicer state: does its field match the field of the slicer with that name on the page?
# Usage: check_bookmarks.py <...\Sales_ClientB.Report\definition> [--quiet]
import json, glob, re, os, sys

d = sys.argv[1]
quiet = '--quiet' in sys.argv

def fields(o):
    return set(re.findall(r'"(?:Property|Hierarchy|Level)": "([^"]+)"', json.dumps(o, ensure_ascii=False)))

pages = {os.path.basename(os.path.dirname(p)): json.load(open(p, encoding='utf-8'))['displayName'].strip()
         for p in glob.glob(f'{d}/pages/*/page.json')}
vis = {}
for f in glob.glob(f'{d}/pages/*/visuals/*/visual.json'):
    j = json.load(open(f, encoding='utf-8'))
    pg = os.path.normpath(f).split(os.sep)[-4]
    if j.get('visual', {}).get('visualType') == 'slicer':
        vis[(pg, j['name'])] = fields(j['visual'].get('query', {}))
res = {}
for b in glob.glob(f'{d}/bookmarks/*.bookmark.json'):
    j = json.load(open(b, encoding='utf-8'))
    pg = j['explorationState'].get('activeSection')
    for n, s in j['explorationState'].get('sections', {}).get(pg, {}).get('visualContainers', {}).items():
        if (pg, n) in vis:
            bf = fields(s.get('filters', {})) | fields(s.get('singleVisual', {}).get('activeProjections', {}))
            if bf:
                r = res.setdefault((pg, j['displayName']), [0, 0])
                r[1] += 1
                r[0] += not (bf & vis[(pg, n)])
bad_total = sum(b for b, _ in res.values())
for (pg, bn), (bad, tot) in sorted(res.items()):
    if bad or not quiet:
        print(f"{'BAD ' if bad else 'ok  '}{pg} {pages.get(pg)} | {bn}: {bad}/{tot}")
print(f'TOTAL mismatched slicer states: {bad_total} / {sum(t for _, t in res.values())}')
