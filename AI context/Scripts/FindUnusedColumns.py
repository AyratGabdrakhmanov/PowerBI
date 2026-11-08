"""Report-only: is every column of a PBIP semantic model used anywhere? Nothing is changed.

usage: python -X utf8 FindUnusedColumns.py <folder with X.SemanticModel and X.Report> [--csv out.csv] [--all]

A column counts as used by (strongest first):
  REPORT     - a visual / filter / sort / bookmark field: {"Column": {SourceRef Entity | alias}, "Property"},
               or a level of a hierarchy that the report uses (HierarchyLevel / Hierarchy)
  DAX        - 'Table'[Column] / Table[Column] in measures, calculated columns, calculated tables
               (field parameters' NAMEOF included), calculation items, RLS filters. DAX comments are
               ignored (block comments nest in DAX: `1 /* a /* b */ c */ + 1` = 2)
  STRUCTURE  - relationship column, sort-by target of a used column, level of an unused hierarchy,
               groupByColumn of a field parameter, key of a date table (isKey). Needed by the model,
               but nothing shows it - review before removing
  M          - only Power Query: another query (a table's M partition or an expressions.tmdl query) references
               this table's query (#"Name" / Name) AND names the column ("Col" / [Col], or its sourceColumn).
               Removing it from the query would break that query - keep
  MAYBE      - only an unqualified [Column] in DAX (could be a row-context column reference)
  UNUSED     - none of the above
For an UNUSED column of a calculated table the "How" hint says where it comes from in the table's DAX: an
own "Col" entry (DATATABLE / ADDCOLUMNS / SELECTCOLUMNS / {...}) - delete that entry; inherited from the source
table - wrap the expression in SELECTCOLUMNS without it; field parameter - internal, keep.
A reference from a measure that is itself unused still counts (run CleanUnused.ps1 first). M text matching is
textual (strings / [field] access), so it over-protects rather than misses.
"""
import argparse, collections, csv, json, pathlib, re, sys

ap = argparse.ArgumentParser()
ap.add_argument('root')
ap.add_argument('--csv')
ap.add_argument('--all', action='store_true', help='print every column, not only UNUSED / MAYBE / STRUCTURE')
args = ap.parse_args()
root = pathlib.Path(args.root)
sm = next(root.glob('*.SemanticModel'), None)
rp = next(root.glob('*.Report'), None)
if not sm or not rp:
    sys.exit(f'Expected X.SemanticModel and X.Report under {root}')
dfn = sm / 'definition'


def unq(s):
    s = s.strip()
    return s[1:-1].replace("''", "'") if s.startswith("'") and s.endswith("'") else s


def split_name(rest):
    """'Name With Spaces' = expr  |  Name = expr  |  Name  -> (name, has_expr)"""
    rest = rest.rstrip()
    if rest.startswith("'"):
        i = 1
        while i < len(rest):
            if rest[i] == "'":
                if i + 1 < len(rest) and rest[i + 1] == "'":
                    i += 2
                    continue
                break
            i += 1
        return rest[1:i].replace("''", "'"), rest[i + 1:].lstrip().startswith('=')
    m = re.match(r'([^=]+?)\s*(=.*)?$', rest)
    return m.group(1).strip(), bool(m.group(2))


def strip_dax_comments(t):
    out, depth, in_str, i, n = [], 0, False, 0, len(t)
    while i < n:
        ch, nx = t[i], t[i + 1] if i + 1 < n else ''
        if depth:
            if ch == '/' and nx == '*': depth += 1; i += 2; continue
            if ch == '*' and nx == '/': depth -= 1; i += 2; continue
            if ch == '\n': out.append(ch)
            i += 1; continue
        if in_str:
            out.append(ch)
            if ch == '"':
                if nx == '"': out.append(nx); i += 2; continue
                in_str = False
            i += 1; continue
        if ch == '"': in_str = True; out.append(ch); i += 1; continue
        if ch == '/' and nx == '*': depth = 1; i += 2; continue
        if (ch == '/' and nx == '/') or (ch == '-' and nx == '-'):
            while i < n and t[i] != '\n': i += 1
            continue
        out.append(ch); i += 1
    return ''.join(out)


# ---------------------------------------------------------------- model
cols = {}                 # (table, col) -> info
hier_levels = {}          # (table, hierarchy) -> {level: column}
measure_names = set()
dax_corpus = []
structure = collections.defaultdict(set)   # (table, col) -> reasons
sort_by = {}              # (table, col) -> sort-by target column
m_queries = {}            # query name -> M text (a table's M partitions, or an expressions.tmdl query)
calc_table_dax = {}       # table -> its calculated partition DAX
fp_tables = set()         # field parameter tables

for f in sorted((dfn / 'tables').glob('*.tmdl')):
    text = f.read_text(encoding='utf-8-sig')
    tm = re.search(r'(?m)^table (.+)$', text)
    if not tm:
        continue
    table = unq(tm.group(1))
    lines = text.splitlines()
    part_kind = {m.group(1) for m in re.finditer(r'(?m)^\tpartition .+? = (\w+)', text)}
    calc_table = 'calculated' in part_kind
    i = 0
    while i < len(lines):
        ln = lines[i]
        # top-level object inside the table: "\t<kind> ..."
        m = re.match(r'^\t(column|measure|hierarchy|partition|calculationItem|calculationGroup)\b ?(.*)$', ln)
        if not m:
            i += 1; continue
        kind, rest = m.group(1), m.group(2)
        j = i + 1
        while j < len(lines) and (lines[j].startswith('\t\t') or not lines[j].strip()):
            j += 1
        block = '\n'.join(lines[i:j])
        if kind == 'column':
            name, has_expr = split_name(rest)
            ctype = 'calculated' if has_expr else ('calc-table' if calc_table else 'data')
            src = re.search(r'(?m)^\t\tsourceColumn: (.+)$', block)
            info = cols[(table, name)] = {'table': table, 'column': name, 'type': ctype,
                                          'hidden': bool(re.search(r'(?m)^\t\tisHidden\s*$', block)), 'uses': collections.Counter(),
                                          'source': unq(src.group(1)).strip('[]') if src else name}
            if 'ParameterMetadata' in block: fp_tables.add(table)
            sb = re.search(r'(?m)^\t\tsortByColumn: (.+)$', block)
            if sb: sort_by[(table, name)] = unq(sb.group(1))
            gb = re.search(r'(?m)^\t\t\tgroupByColumn: (.+)$', block)
            if gb: structure[(table, unq(gb.group(1)))].add('groupByColumn')
            if re.search(r'(?m)^\t\tisKey\s*$', block): structure[(table, name)].add('isKey')
            if has_expr: dax_corpus.append(block)
        elif kind == 'measure':
            measure_names.add(split_name(rest)[0])
            dax_corpus.append(block)
        elif kind == 'hierarchy':
            hn = unq(rest)
            lv = {}
            for lm in re.finditer(r'(?m)^\t\tlevel (.+)\n(?:\t\t\t.*\n)*?\t\t\tcolumn: (.+)$', block + '\n'):
                lv[unq(lm.group(1))] = unq(lm.group(2))
            hier_levels[(table, hn)] = lv
        elif kind == 'partition':
            if re.search(r'= calculated', rest):
                dax_corpus.append(block)
                calc_table_dax[table] = calc_table_dax.get(table, '') + block
            elif re.search(r'= m\b', rest):
                m_queries[table] = m_queries.get(table, '') + block + '\n'
        elif kind in ('calculationItem', 'calculationGroup'):
            dax_corpus.append(block)
        i = j

ex = dfn / 'expressions.tmdl'
if ex.exists():
    for m in re.finditer(r'(?ms)^expression (.+?) =(.*?)(?=^expression |\Z)', ex.read_text(encoding='utf-8-sig')):
        m_queries[unq(m.group(1))] = m.group(2)

for f in (dfn / 'roles').glob('*.tmdl') if (dfn / 'roles').exists() else []:
    dax_corpus.append(f.read_text(encoding='utf-8-sig'))

rel = dfn / 'relationships.tmdl'
if rel.exists():
    for m in re.finditer(r'(?m)^\t(?:from|to)Column: (.+)$', rel.read_text(encoding='utf-8-sig')):
        s = m.group(1).strip()
        if s.startswith("'"):
            k = s.index("'.", 1) if "'." in s else s.rfind('.')
            t, c = s[1:k].replace("''", "'"), s[k + 2:]
        else:
            t, c = s.split('.', 1)
        structure[(t, unq(c))].add('relationship')

for (t, h), lv in hier_levels.items():
    for c in lv.values():
        structure[(t, c)].add(f'hierarchy {h}')

# ---------------------------------------------------------------- DAX references
dax = strip_dax_comments('\n'.join(dax_corpus))
qualified = collections.Counter()
for m in re.finditer(r"(?:'((?:[^']|'')+)'|(?<![\w'\]])([A-Za-z_][\w.]*))\[([^\[\]]+)\]", dax):
    t = (m.group(1) or '').replace("''", "'") or m.group(2)
    qualified[(t, m.group(3))] += 1
unqualified = collections.Counter(m.group(1) for m in re.finditer(r"(?<![\w'\]])\[([^\[\]]+)\]", dax))
tables_lower = {t.lower(): t for t, _ in cols}

# ---------------------------------------------------------------- report references
report_refs = collections.Counter(); report_files = collections.defaultdict(set); bm_only = collections.defaultdict(set)
hier_used = set()


def walk(o, f, al):
    if isinstance(o, dict):
        if isinstance(o.get('From'), list):
            al = dict(al); al.update({x.get('Name'): x.get('Entity') for x in o['From'] if isinstance(x, dict)})
        for key in ('Column', 'HierarchyLevel', 'Hierarchy'):
            c = o.get(key)
            if not isinstance(c, dict):
                continue
            if key == 'Column' and 'Property' in c:
                sr = c.get('Expression', {}).get('SourceRef', {})
                e = sr.get('Entity') or al.get(sr.get('Source'))
                hit = [(e, c['Property'])]
            elif key == 'HierarchyLevel':
                h = c.get('Expression', {}).get('Hierarchy', {})
                sr = h.get('Expression', {}).get('SourceRef', {})
                e = sr.get('Entity') or al.get(sr.get('Source'))
                col = hier_levels.get((e, h.get('Hierarchy')), {}).get(c.get('Level'))
                hier_used.add((e, h.get('Hierarchy')))
                hit = [(e, col)] if col else []
            elif key == 'Hierarchy' and isinstance(c.get('Hierarchy'), str):
                sr = c.get('Expression', {}).get('SourceRef', {})
                e = sr.get('Entity') or al.get(sr.get('Source'))
                hier_used.add((e, c['Hierarchy']))
                hit = [(e, lc) for lc in hier_levels.get((e, c['Hierarchy']), {}).values()]
            else:
                hit = []
            for k in hit:
                report_refs[k] += 1; report_files[k].add(f)
        for v in o.values():
            walk(v, f, al)
    elif isinstance(o, list):
        for v in o:
            walk(v, f, al)


for jf in (rp / 'definition').rglob('*.json'):
    try:
        walk(json.loads(jf.read_text(encoding='utf-8-sig')), jf.relative_to(rp / 'definition').as_posix(), {})
    except json.JSONDecodeError:
        print(f'  skipped (not JSON): {jf}')

# ---------------------------------------------------------------- Power Query (M) references
def strip_m_comments(t):
    """M comments out, strings kept (column names live in strings)."""
    out, i, n, in_str = [], 0, len(t), False
    while i < n:
        ch, nx = t[i], t[i + 1] if i + 1 < n else ''
        if in_str:
            out.append(ch)
            if ch == '"':
                if nx == '"': out.append(nx); i += 2; continue
                in_str = False
            i += 1; continue
        if ch == '"': in_str = True; out.append(ch); i += 1; continue
        if ch == '/' and nx == '*':
            j = t.find('*/', i + 2); i = n if j < 0 else j + 2; continue
        if ch == '/' and nx == '/':
            while i < n and t[i] != '\n': i += 1
            continue
        out.append(ch); i += 1
    return ''.join(out)


m_clean = {q: strip_m_comments(txt) for q, txt in m_queries.items()}


def m_refers_to(text, query):
    """Does M text reference the query `query` - #"Name" or a bare identifier Name?"""
    q = f'#"{query.replace(chr(34), chr(34) * 2)}"'
    bare = bool(re.match(r'^[A-Za-z_][\w.]*$', query))
    # a step of this query with the same name (`Accounts = Source{...}`) shadows the other query - a local
    # step, not a reference (Finance Dim_P&L: its own SQL step "Accounts", 2026-10-23)
    if re.search(r'(?m)^\s*(?:' + re.escape(q) + (r'|' + re.escape(query) if bare else '') + r')\s*=', text):
        return False
    if q in text:
        return True
    return bare and bool(re.search(r'(?<![\w#".])' + re.escape(query) + r'(?![\w"])', text))


m_users = {q: [o for o in m_clean if o != q and m_refers_to(m_clean[o], q)] for q in m_clean}
m_hits = collections.defaultdict(list)   # (table, col) -> other queries naming it
for (t, c), info in cols.items():
    if t not in m_clean:
        continue
    names = {c, info['source']}
    for o in m_users.get(t, []):
        txt = m_clean[o]
        if any(f'"{x}"' in txt or f'[{x}]' in txt for x in names):
            m_hits[(t, c)].append(o)


def calc_hint(t, c):
    if t in fp_tables:
        return 'field parameter column - internal, keep'
    dax_t = calc_table_dax.get(t, '')
    if re.search(r'"' + re.escape(c) + r'"', dax_t):
        return f'delete the "{c}" entry in the table DAX'
    return 'inherited from the source table - wrap the DAX in SELECTCOLUMNS without it'


# ---------------------------------------------------------------- verdicts
for key, info in cols.items():
    t, c = key
    info['m'] = sorted(set(m_hits.get(key, [])))
    info['report'] = report_refs.get(key, 0)
    info['bookmark_only'] = bool(report_files.get(key)) and all(p.startswith('bookmarks/') for p in report_files[key])
    info['dax'] = sum(n for (qt, qc), n in qualified.items() if qt.lower() == t.lower() and qc.lower() == c.lower())
    info['unqualified'] = 0 if c in measure_names else unqualified.get(c, 0)
    info['structure'] = set(structure.get(key, set()))

used = lambda i: i['report'] or i['dax']
# sort-by target / hierarchy level count only for a USED column / hierarchy
for (t, c), target in sort_by.items():
    if (t, target) in cols:
        cols[(t, target)]['structure'].add('sortBy of ' + c + ('' if used(cols[(t, c)]) else ' (unused)'))


def verdict(i):
    if i['report'] or i['dax']:
        return 'USED'
    s = {r for r in i['structure'] if not r.endswith('(unused)')}
    if s:
        return 'STRUCTURE'
    if i['m']:
        return 'M'
    if i['unqualified']:
        return 'MAYBE'
    return 'UNUSED'


rows = []
for (t, c), i in sorted(cols.items(), key=lambda kv: (kv[0][0].lower(), kv[0][1].lower())):
    v = verdict(i)
    rows.append({'Table': t, 'Column': c, 'Type': i['type'], 'Hidden': i['hidden'], 'Verdict': v,
                 'ReportRefs': i['report'], 'BookmarkOnly': i['bookmark_only'], 'DaxRefs': i['dax'],
                 'UnqualifiedRefs': i['unqualified'], 'Structure': '; '.join(sorted(i['structure'])),
                 'UsedByQueries': ', '.join(i['m']),
                 'How': calc_hint(t, c) if v == 'UNUSED' and i['type'] == 'calc-table' else ''})

cnt = collections.Counter(r['Verdict'] for r in rows)
print(f"Columns: {len(rows)}  " + '  '.join(f'{k} {cnt[k]}' for k in ('USED', 'STRUCTURE', 'M', 'MAYBE', 'UNUSED')))
print()
for v in ('UNUSED', 'MAYBE', 'M', 'STRUCTURE') + (('USED',) if args.all else ()):
    sel = [r for r in rows if r['Verdict'] == v]
    if not sel:
        continue
    print(f'== {v} ({len(sel)})')
    for r in sel:
        extra = []
        if r['Structure']: extra.append(r['Structure'])
        if r['UnqualifiedRefs']: extra.append(f"[{r['Column']}] x{r['UnqualifiedRefs']}")
        if r['BookmarkOnly']: extra.append('bookmarks only')
        if r['UsedByQueries']: extra.append('read by query: ' + r['UsedByQueries'])
        if r['How']: extra.append(r['How'])
        print(f"  {r['Table']}[{r['Column']}]  {r['Type']}{' hidden' if r['Hidden'] else ''}" + (f"  - {'; '.join(extra)}" if extra else ''))
    print()
bmo = [r for r in rows if r['BookmarkOnly'] and not r['DaxRefs']]
if bmo:
    print(f'NOTE: {len(bmo)} column(s) are referenced only from bookmarks (saved state) - effectively unused if the bookmarks go.')
if args.csv:
    with open(args.csv, 'w', newline='', encoding='utf-8-sig') as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
    print(f'CSV: {args.csv}')
