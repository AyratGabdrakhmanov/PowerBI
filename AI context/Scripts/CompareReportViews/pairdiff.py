# Diff one cur result vs one pdf result: rows keyed by their text columns, numeric columns compared by short name.
# python pairdiff.py cur_81 pdf_47 [cur_x pdf_y ...]
import json, os, re, sys

here = os.path.dirname(os.path.abspath(__file__))
res = json.load(open(os.path.join(here, 'results.json'), encoding='utf-8-sig'))


def short(c):
    c = c.split('[')[-1].rstrip(']')
    return re.sub(r'(_He|2)$', '', c).replace('Quantity_DocSales', 'Sales_Lines').replace('MonthYear', 'Month Year')


def num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def table(i):
    r = res[i]
    cols = [short(c) for c in r['cols']]
    rows = r['rows']
    isnum = [all(num(row[k]) is not None or row[k] in (None, '') for row in rows) and any(num(row[k]) is not None for row in rows) for k in range(len(cols))]
    keyidx = [k for k in range(len(cols)) if not isnum[k] and not cols[k].startswith(('IsGrandTotal', 'IsDM', 'SortBy'))]
    d = {}
    for row in rows:
        d[tuple(row[k] or '' for k in keyidx)] = {cols[k]: num(row[k]) for k in range(len(cols)) if isnum[k] and not cols[k].startswith(('IsGrandTotal', 'IsDM', 'SortBy'))}
    return cols, d


args = sys.argv[1:]
for a, b in zip(args[::2], args[1::2]):
    ca, da = table(a)
    cb, db = table(b)
    common = sorted(set().union(*[set(v) for v in da.values()] or [set()]) & set().union(*[set(v) for v in db.values()] or [set()]))
    print(f'==== {a} ({len(da)} rows) vs {b} ({len(db)} rows); numeric cols compared: {common}')
    only_a = [k for k in da if k not in db]
    only_b = [k for k in db if k not in da]
    if only_a:
        print(f'  rows only in cur ({len(only_a)}): {only_a[:6]}')
    if only_b:
        print(f'  rows only in pdf ({len(only_b)}): {only_b[:6]}')
    for c in common:
        sa = sum(v.get(c) or 0 for v in da.values()); sb = sum(v.get(c) or 0 for v in db.values())
        diffs = [(k, da[k].get(c), db[k].get(c)) for k in da if k in db and abs((da[k].get(c) or 0) - (db[k].get(c) or 0)) > 0.005]
        flag = 'OK ' if not diffs and abs(sa - sb) < 0.01 else 'DIFF'
        print(f'  {flag} {c}: sum cur {sa:,.2f} | pdf {sb:,.2f} | rows differing {len(diffs)}' + (f' e.g. {diffs[0]}' if diffs else ''))
    only_cols_a = sorted(set().union(*[set(v) for v in da.values()] or [set()]) - set(common))
    only_cols_b = sorted(set().union(*[set(v) for v in db.values()] or [set()]) - set(common))
    if only_cols_a or only_cols_b:
        print(f'  columns only cur: {only_cols_a} | only pdf: {only_cols_b}')
