# Compare visual results of the two reports (values only, column names ignored, rows sorted, numbers rounded).
import json, os, re
from collections import defaultdict

here = os.path.dirname(os.path.abspath(__file__))
qs = {q['id']: q for q in json.load(open(os.path.join(here, 'queries.json'), encoding='utf-8'))}
res = json.load(open(os.path.join(here, 'results.json'), encoding='utf-8-sig'))


def norm(v):
    if v is None:
        return ''
    try:
        f = float(v)
        return f'{round(f, 2):.2f}'
    except ValueError:
        return v


def key(r):
    return tuple(sorted(tuple(norm(x) for x in row) for row in r['rows']))


def measures(q):
    return sorted(set(re.findall(r"\"([^\"]+)\", \[?'?[\w ]*'?\[?([^\]\n]+)\]", q)))


by = defaultdict(list)
for i, r in res.items():
    by[qs[i]['rep']].append(i)
keys = {i: key(res[i]) for i in res}
pdf_keys = defaultdict(list)
for i in by['pdf']:
    pdf_keys[keys[i]].append(i)
cur_keys = {keys[i] for i in by['cur']}

same = other = 0
missing = []
for i in by['cur']:
    hits = pdf_keys.get(keys[i], [])
    if any(qs[h]['page'] == qs[i]['page'] for h in hits):
        same += 1
    elif hits:
        other += 1
    else:
        missing.append(i)
pdf_only = [i for i in by['pdf'] if keys[i] not in cur_keys]
print(f'cur results: {len(by["cur"])}  matched on the same page: {same}  matched on another page: {other}  NO MATCH: {len(missing)}')
print(f'pdf results with no match in cur: {len(pdf_only)}')


def show(i):
    r = res[i]
    q = qs[i]['query']
    cols = r['cols']
    print(f'  [{qs[i]["page"]}] {i}: {len(r["rows"])} rows, cols: {", ".join(c.split("[")[-1].rstrip("]") for c in cols)[:200]}')


print('\n== cur results with no identical pdf result')
for i in sorted(missing, key=lambda x: (qs[x]['page'] or '', x)):
    show(i)
print('\n== pdf results with no identical cur result')
for i in sorted(pdf_only, key=lambda x: (qs[x]['page'] or '', x)):
    show(i)
