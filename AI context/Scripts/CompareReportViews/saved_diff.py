# Saved slicer selections + visual-level date filters: approved PDF report vs main Sales Report (same page / visual names).
import glob, json, os, re, sys

pdf_root, cur_root = sys.argv[1], sys.argv[2]


def saved(root):
    out = {}
    for p in glob.glob(os.path.join(root, 'definition', 'pages', '*', 'visuals', '*', 'visual.json')):
        j = json.load(open(p, encoding='utf-8'))
        pg = os.path.normpath(p).split(os.sep)[-4]
        vis = j.get('visual', {})
        sel = [g['properties']['filter'] for g in vis.get('objects', {}).get('general', []) if 'filter' in g.get('properties', {})]
        vals = sorted(set(re.findall(r'"Value": "([^"]+)"', json.dumps(sel, ensure_ascii=False)))) if sel else []
        fields = sorted(set(re.findall(r'"Property": "([^"]+)"', json.dumps(sel, ensure_ascii=False)))) if sel else []
        dates = sorted(set(re.findall(r"datetime'([^']+)'", json.dumps(j.get('filterConfig', {}), ensure_ascii=False))))
        out[(pg, j['name'])] = (vis.get('visualType'), vals, dates, fields)
    return out


pdf, cur = saved(pdf_root), saved(cur_root)
n = 0
for k in sorted(pdf):
    a, b = pdf[k], cur.get(k)
    if b is None:
        continue
    if (a[1] and a[1] != b[1]) or (a[2] and a[2] != b[2]):
        n += 1
        print(k, a[0])
        print('    pdf:', a[3], a[1][:6], a[2])
        print('    cur:', b[3], b[1][:6], b[2])
print('visuals with a lost / changed saved selection:', n)
