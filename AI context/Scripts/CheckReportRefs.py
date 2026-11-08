# Read-only: report field references (measures, columns, hierarchies / levels) that do not exist in the
# semantic model - what Desktop shows as broken visuals / filter warnings. With --before (a backup of the
# same report, e.g. taken before an edit) each missing field is marked NEW or "old" (was missing before too),
# so new breakage stands out from long-broken junk.
# Walks every *.json of the report (visuals, pages, filters, bookmarks, report.json) as JSON; "Source"
# aliases of filters ("From": [{"Name": "c", "Entity": "X"}]) are resolved. Names compare case-insensitively.
#
# Usage:
#   python -I -X utf8 CheckReportRefs.py <X.Report> [--model <X.SemanticModel>] [--before <backup X.Report>] [--new-only]
# --model defaults to the sibling <X>.SemanticModel. Exit code 1 when a NEW missing field is found.
#
# SCRIPT_VERSION: 2026-10-20.1
import argparse, json, re, sys
from collections import defaultdict
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')
ap = argparse.ArgumentParser()
ap.add_argument('report'); ap.add_argument('--model'); ap.add_argument('--before'); ap.add_argument('--new-only', action='store_true')
a = ap.parse_args()
rep = Path(a.report)
sm = Path(a.model) if a.model else rep.with_name(rep.name[:-len('.Report')] + '.SemanticModel')


def unq(n): return n[1:-1].replace("''", "'") if n.startswith("'") else n


def model_fields(sm):
    """{table: {field}} lower-case; fields = columns, measures, hierarchies, levels."""
    out = {}
    for f in (sm / 'definition/tables').glob('*.tmdl'):
        t = f.read_text(encoding='utf-8-sig')
        m = re.search(r"^table\s+('[^']*'|[^\r\n]+?)\s*$", t, re.M)
        name = unq(m.group(1).strip()) if m else f.stem
        fields = {unq(x.group(2)).lower() for x in
                  re.finditer(r"^\t+(column|measure|hierarchy|level|calculationItem)\s+('[^']*'|[^\s=]+)", t, re.M)}
        out[name.lower()] = fields
    return out


def refs(root):
    """{(table, field): set(files)} for every Measure / Column / Hierarchy / HierarchyLevel reference."""
    found = defaultdict(set)

    def entity(expr, alias):
        sr = (expr or {}).get('SourceRef') or {}
        return sr.get('Entity') or alias.get(sr.get('Source'))

    def walk(o, alias, f):
        if isinstance(o, dict):
            if isinstance(o.get('From'), list):
                alias = {**alias, **{x.get('Name'): x.get('Entity') for x in o['From'] if isinstance(x, dict)}}
            for k in ('Measure', 'Column'):
                v = o.get(k)
                if isinstance(v, dict) and 'Property' in v:
                    e = entity(v.get('Expression'), alias)
                    if e: found[(e.lower(), v['Property'].lower())].add(f)
            v = o.get('HierarchyLevel')
            if isinstance(v, dict):
                h = ((v.get('Expression') or {}).get('Hierarchy')) or {}
                e = entity(h.get('Expression'), alias)
                if e:
                    found[(e.lower(), str(h.get('Hierarchy', '')).lower())].add(f)
                    found[(e.lower(), str(v.get('Level', '')).lower())].add(f)
            for x in o.values(): walk(x, alias, f)
        elif isinstance(o, list):
            for x in o: walk(x, alias, f)

    for f in root.rglob('*.json'):
        try: walk(json.loads(f.read_text(encoding='utf-8-sig')), {}, f.relative_to(root))
        except ValueError: print('WARN not JSON:', f.relative_to(root))
    return found


def page_names(root):
    out = {}
    for pj in root.glob('definition/pages/*/page.json'):
        try: out[pj.parent.name] = json.loads(pj.read_text(encoding='utf-8-sig')).get('displayName', pj.parent.name)
        except ValueError: pass
    return out


fields = model_fields(sm)
def missing(found): return {k: v for k, v in found.items() if k[0] not in fields or k[1] not in fields[k[0]]}

now = missing(refs(rep))
old = set(missing(refs(Path(a.before)))) if a.before else None
pages = page_names(rep)
new_n = 0
for (t, c), files in sorted(now.items()):
    tag = '' if old is None else ('NEW ' if (t, c) not in old else 'old ')
    new_n += tag == 'NEW '
    if a.new_only and tag != 'NEW ': continue
    pg = sorted({pages.get(p.parts[2], p.parts[2]) if len(p.parts) > 2 and p.parts[1] == 'pages' else str(p) for p in files})
    print(f"{tag}{t}[{c}]  files={len(files)}  {', '.join(pg[:5])}{' ...' if len(pg) > 5 else ''}")
print(f"\nMissing fields: {len(now)}" + ('' if old is None else f"  NEW: {new_n}  old: {len(now) - new_n}")
      + ('' if old is None else f"  fixed since before: {len(old - set(now))}"))
sys.exit(1 if new_n else 0)
