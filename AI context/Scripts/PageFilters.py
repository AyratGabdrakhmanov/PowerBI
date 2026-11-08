"""Print visual-level filters and saved slicer selections of one page (read-only) - pbix (legacy Report/Layout) or PBIR.
Use it to compare a page in an original .pbix with the same page in the PBIP.

Usage:  python -I -X utf8 PageFilters.py <X.pbix | X.Report> "<page display name>"

Change log:
  2026-11-01  created (ClientC: Matanya 3 agent slicer original vs Sales NEW)
"""
import glob, json, os, re, sys, zipfile

src, page = sys.argv[1], sys.argv[2]


def vals(f):
    out = []
    for w in (f.get('filter') or {}).get('Where', []):
        s = json.dumps(w.get('Condition', {}), ensure_ascii=False)
        out += re.findall(r'"Value": "([^"]*)"', s)
    return out


def show(label, filters):
    for f in filters or []:
        col = f.get('expression', {}).get('Column', {}).get('Property') or f.get('expression', {}).get('Measure', {}).get('Property')
        v = vals(f)
        if v:
            print(f'  {label}: {col} [{len(v)}] {", ".join(v)}')


if src.endswith('.pbix'):
    lay = json.loads(zipfile.ZipFile(src).read('Report/Layout').decode('utf-16-le'))
    for s in lay['sections']:
        if s['displayName'] != page:
            continue
        for vc in s['visualContainers']:
            cfg = json.loads(vc['config'])
            sv = cfg.get('singleVisual', {})
            vt = sv.get('visualType')
            show(f'{vt} filter', json.loads(vc.get('filters', '[]')))
            if vt == 'slicer':
                g = sv.get('objects', {}).get('general', [{}])[0].get('properties', {})
                if 'filter' in g:
                    v = vals(g['filter'])
                    print(f'  slicer selection [{len(v)}]: {", ".join(v)}')
else:
    for pj in glob.glob(os.path.join(src, 'definition/pages/*/page.json')):
        if json.load(open(pj, encoding='utf-8'))['displayName'] != page:
            continue
        for vj in glob.glob(os.path.join(os.path.dirname(pj), 'visuals/*/visual.json')):
            v = json.load(open(vj, encoding='utf-8'))
            vt = v['visual']['visualType']
            show(f'{vt} filter', (v.get('filterConfig') or {}).get('filters'))
            if vt == 'slicer':
                g = v['visual'].get('objects', {}).get('general', [{}])[0].get('properties', {})
                if 'filter' in g:
                    x = vals(g['filter'])
                    print(f'  slicer selection [{len(x)}]: {", ".join(x)}')
