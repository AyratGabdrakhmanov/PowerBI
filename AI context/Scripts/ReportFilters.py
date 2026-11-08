"""List the filters of a PBIR report: report level, page level and visual level (read-only).

Usage:  python -I -X utf8 ReportFilters.py <X.Report> [--pages "Page A,Page B"] [--field <text>] [--all-visuals]
  --pages        only pages with these display names (or folder ids)
  --field        only filters whose Table[Column] contains this text (e.g. CT_AreaManager)
  --all-visuals  also list visuals without filters, with their fields (to see why a visual is blank)
Prints one line per filter: Table[Column] <condition> [hidden]. Answers "why is this page / visual blank".

Change log:
  2026-11-01  created (ClientC Sales NEW: blank team pages under a document-agent filter)
"""
import argparse, glob, json, os, re, sys

COMPARE = {0: '=', 1: '>', 2: '>=', 3: '<', 4: '<='}


def lit(v):
    s = v.get('Literal', {}).get('Value', '?') if isinstance(v, dict) else str(v)
    return s[:-1] if re.fullmatch(r'-?\d+[LD]', s) else s


def cond(c):
    """Render a filter Where condition as short text."""
    if not isinstance(c, dict):
        return '?'
    if 'Not' in c:
        return 'NOT (' + cond(c['Not'].get('Expression')) + ')'
    if 'And' in c:
        return cond(c['And']['Left']) + ' AND ' + cond(c['And']['Right'])
    if 'Or' in c:
        return cond(c['Or']['Left']) + ' OR ' + cond(c['Or']['Right'])
    if 'In' in c:
        vals = [lit(v[0]) for v in c['In'].get('Values', [])]
        return 'IN ' + ', '.join(vals) if vals else 'IN (table)'
    if 'Comparison' in c:
        k = c['Comparison']
        return COMPARE.get(k.get('ComparisonKind'), '?') + ' ' + lit(k.get('Right'))
    if 'Contains' in c:
        return 'CONTAINS ' + lit(c['Contains'].get('Right'))
    return next(iter(c), '?')


def field(f):
    s = json.dumps(f.get('field', {}), ensure_ascii=False)
    t = (re.findall(r'"Entity": "([^"]+)"', s) or ['?'])[0]
    p = (re.findall(r'"Property": "([^"]+)"', s) or ['?'])[-1]
    return f'{t}[{p}]'


def filters(fc, flt):
    out = []
    for f in (fc or {}).get('filters', []):
        name = field(f)
        if flt and flt.lower() not in name.lower():
            continue
        where = f.get('filter', {}).get('Where', [])
        text = ' AND '.join(cond(w.get('Condition')) for w in where) or '(no condition: ' + f.get('type', '?') + ')'
        out.append(f'{name} {text}' + ('  [hidden]' if f.get('isHiddenInViewMode') else ''))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('report')
    ap.add_argument('--pages')
    ap.add_argument('--field')
    ap.add_argument('--all-visuals', action='store_true')
    a = ap.parse_args()
    d = os.path.join(a.report, 'definition')
    want = set(x.strip() for x in a.pages.split(',')) if a.pages else None

    rj = json.load(open(os.path.join(d, 'report.json'), encoding='utf-8-sig'))
    print('REPORT')
    for line in filters(rj.get('filterConfig'), a.field):
        print('  ' + line)

    for pj_path in sorted(glob.glob(os.path.join(d, 'pages', '*', 'page.json'))):
        pdir = os.path.dirname(pj_path)
        pj = json.load(open(pj_path, encoding='utf-8-sig'))
        if want and pj.get('displayName') not in want and os.path.basename(pdir) not in want:
            continue
        lines = ['  page: ' + x for x in filters(pj.get('filterConfig'), a.field)]
        for vp in sorted(glob.glob(os.path.join(pdir, 'visuals', '*', 'visual.json'))):
            vj = json.load(open(vp, encoding='utf-8-sig'))
            v = vj.get('visual', {})
            fl = filters(vj.get('filterConfig'), a.field)
            if not fl and not a.all_visuals:
                continue
            props = sorted(set(re.findall(r'"Property": "([^"]+)"', json.dumps(v.get('query', {}), ensure_ascii=False))))
            lines.append(f"  visual {v.get('visualType', '?')} {os.path.basename(os.path.dirname(vp))}"
                         + (f" fields: {', '.join(props)}" if a.all_visuals else ''))
            lines += ['      ' + x for x in fl]
        if lines or want:
            print(f"PAGE {pj.get('displayName')} ({os.path.basename(pdir)})")
            print('\n'.join(lines))


if __name__ == '__main__':
    sys.exit(main())
