"""Repoint PBIR report references of measures moved to another table (Entity, aliased Source, queryRef / metadata
strings, bookmarks). Move the measures in the model first (TOM: Clone -> Remove -> Add, see PBIP_Scripts.md).
usage: python MoveMeasureRefs.py <Report dir with *.Report> --from Currency --to JournalEntries
                                 --measures "Debit JE" "Credit JE" Balance [--apply]"""
import argparse, datetime, json, pathlib, re, shutil

ap = argparse.ArgumentParser()
ap.add_argument('report'); ap.add_argument('--from', dest='old', required=True); ap.add_argument('--to', dest='new', required=True)
ap.add_argument('--measures', nargs='+', required=True); ap.add_argument('--apply', action='store_true')
# --whole-table (2026-10-24): the old table held ONLY measures and is deleted (ClientB KeyData -> _Measures): afterwards
# every remaining "Entity": OLD and every "OLD." string (labels of long-gone measures, aliases the walk misses) -> NEW
ap.add_argument('--whole-table', action='store_true')
a = ap.parse_args()
rep = pathlib.Path(a.report); defn = next(rep.glob('*.Report')) / 'definition'
OLD, NEW, MOVED = a.old, a.new, set(a.measures)
# "Old.Measure" ends at a quote, ")" or "," - the last one inside visual calculations such as
# Divide(KeyData.SalesValue, ScopedEval(KeyData.SalesValue, ...)) (2026-10-24, ClientB)
STR = re.compile(r'(?<![\w.])' + re.escape(OLD) + r'\.(' + '|'.join(map(re.escape, sorted(MOVED, key=len, reverse=True))) + r')(?=["\),])')
ALIAS = '__mv'
stats = {'entity': 0, 'alias': 0, 'strings': 0, 'unused_from': 0}

def uses(o, name):
    if isinstance(o, dict): return o.get('Source') == name or any(uses(v, name) for v in o.values())
    if isinstance(o, list): return any(uses(v, name) for v in o)
    return False

def drop_unused_from(o):
    """After the move an alias of OLD may be referenced by nothing - drop it (it would point at a table that is
    deleted next, e.g. a pure measure table). 2026-10-24, ClientB KeyData."""
    if isinstance(o, dict):
        if isinstance(o.get('From'), list):
            rest = {k: v for k, v in o.items() if k != 'From'}
            keep = [x for x in o['From'] if not (isinstance(x, dict) and x.get('Entity') == OLD and not uses(rest, x.get('Name')))]
            stats['unused_from'] += len(o['From']) - len(keep); o['From'] = keep
        for v in o.values(): drop_unused_from(v)
    elif isinstance(o, list):
        for v in o: drop_unused_from(v)

WHOLE = re.compile(r'(?<![\w.])' + re.escape(OLD) + r'\.')

def whole_table(o):
    items = o.items() if isinstance(o, dict) else enumerate(o) if isinstance(o, list) else []
    for k, v in list(items):
        if k == 'Entity' and v == OLD: o[k] = NEW; stats['entity'] += 1
        elif isinstance(v, str):
            nv, n = WHOLE.subn(NEW + '.', v)
            if n: o[k] = nv; stats['strings'] += n
        else: whole_table(v)

def fix(o, aliases):
    """Returns True when an aliased ref was moved to ALIAS (the enclosing From then gets an entry for NEW)."""
    need = False
    if isinstance(o, dict):
        if isinstance(o.get('From'), list):
            aliases = {**aliases, **{x['Name']: x for x in o['From'] if isinstance(x, dict) and 'Name' in x}}
            if any([fix(v, aliases) for k, v in o.items() if k != 'From']) and not any(x.get('Name') == ALIAS for x in o['From']):
                o['From'].append({'Name': ALIAS, 'Entity': NEW, 'Type': 0})
            return False
        ms = o.get('Measure')
        if isinstance(ms, dict) and ms.get('Property') in MOVED:
            sr = ms['Expression']['SourceRef']
            if sr.get('Entity') == OLD:
                sr['Entity'] = NEW; stats['entity'] += 1
            elif aliases.get(sr.get('Source'), {}).get('Entity') == OLD:
                sr['Source'] = ALIAS; stats['alias'] += 1; need = True
        for v in o.values():
            need |= fix(v, aliases)
    elif isinstance(o, list):
        for v in o:
            need |= fix(v, aliases)
    return need

writes = {}
for p in defn.rglob('*.json'):
    raw = p.read_bytes(); txt = raw.decode('utf-8-sig')
    if f'"{OLD}"' not in txt and f'{OLD}.' not in txt:
        continue
    j = json.loads(txt); before = json.dumps(j, ensure_ascii=False)
    fix(j, {}); drop_unused_from(j)
    if a.whole_table: whole_table(j)
    s, n = STR.subn(NEW + r'.\1', json.dumps(j, ensure_ascii=False, indent=2)); stats['strings'] += n
    if json.dumps(json.loads(s), ensure_ascii=False) != before:
        writes[p] = (s, raw)
print(stats, 'files', len(writes))
for p in writes:
    print('  ', p.relative_to(defn))

if a.apply:
    bk = rep.parent / 'BackUp' / f'MoveMeasureRefs_{datetime.datetime.now():%Y-%m-%d_%H%M%S}'
    for p, (s, raw) in writes.items():
        t = bk / p.relative_to(defn); t.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(p, t)
        nl = b'\r\n' if b'\r\n' in raw else b'\n'
        p.write_bytes(s.encode('utf-8').replace(b'\n', nl) + nl)   # keep the file's line endings
    print('applied, backup', str(bk).encode('ascii', 'backslashreplace').decode())   # Cyrillic path on a cp1252 console
