# PBIR report fields and filters - one tool, three sub-commands (2026-10-16; merged from
# ReplaceReportField.py 2026-10-16.3, DropReportFilters.py 2026-10-16.1, CleanReportFilters.py 2026-10-15.1).
#
#   replace        replace a column / hierarchy level with another everywhere in the report; with bare
#                  table names - every shared column / level (table mode), or a rename when --from is
#                  no longer in the model
#   drop-filters   drop every filter on a column (visual / page / report filters, bookmark states) and
#                  list what was dropped as a Markdown test checklist
#   clean-filters  remove Filters-pane cards that filter nothing and are not used
#   refs           count report references per column / level of one table (read-only)
#
# Usage:
#   python -I ReportFields.py replace <X.Report> --from "Customers[CodeNameBP]" --to "Customers[CardName]" [--apply]
#   python -I ReportFields.py replace <X.Report> --from "Customers[CardName]" --to "Customers[CardHierarchy][CardName]" --visuals slicer57,slicer88
#   python -I ReportFields.py replace <X.Report> --from Customers --to CustomersSmall --skip CardCode
#   python -I ReportFields.py drop-filters <X.Report> --field "Customers[CardType]" --list Dropped.md [--apply]
#   python -I ReportFields.py clean-filters <X.Report> [--pages Page2,Page3] [--no-visuals] [--no-pages] [--apply]
#   python -I ReportFields.py refs <X.Report> --table Customers
# Every sub-command: dry run by default, --apply writes; backup of the report to the nearest "BackUp"
# folder above it (--backup-dir to override) -> ReplaceField_<x> / DropFilters_<x> / CleanReportFilters_<ts>;
# pbir validate before / after; only changed files are written, keeping CRLF / BOM / trailing newline.
# After --apply with Desktop open: powerbi-desktop status (no unsaved changes) -> powerbi-desktop reload.
# Table swaps are normally run through ReplaceModelTable.ps1 (model side + this tool).
#
# replace - lessons built in:
#   - "Source": "c" aliases inside filters are resolved through the filter's "From" list; another table
#     gets its own "From" entry (c taken -> c1), an entry nothing references any more is dropped;
#   - a hierarchy level as --from also replaces its column where Desktop writes the column (identityKeys,
#     saved slicer selection); identityKeys stay a Column;
#   - the target field must exist in the sibling X.SemanticModel;
#   - table mode: a column whose dataType differs is skipped (saved literals would no longer match); a
#     calculated column (no dataType in TMDL) is not checked;
#   - names match case-insensitively, as in Power BI (a TopN filter with "CardCreateDate" for the column
#     CardCreatedate);
#   - a queryRef match must not continue with a space / dot / dash (Customers.CardGroup must not hit
#     "Customers.CardGroup Category"); nativeQueryRef is renamed only in the projection whose field was
#     replaced.
# drop-filters - only filters; a field also used in a query / sort / formatting is listed as "still used".
# clean-filters - a card is unused when it has no "filter" condition and: visual card - its field is not in
#   the visual's query; page card - no bookmark applies a condition to it. Bookmark entries of removed
#   page cards (no condition) go too. Report-level cards are only listed. A file whose JSON would not
#   round-trip byte-identically is skipped. Related: CleanUnused.ps1 Step 9.
#
# SCRIPT_VERSION: 2026-10-23.1
import argparse, glob, json, os, re, shutil, subprocess, sys
from datetime import datetime

sys.stdout.reconfigure(encoding='utf-8')


# ============================================================ shared
def load(p):
    raw = open(p, 'rb').read()
    return raw, json.loads(raw.decode('utf-8-sig'))


def dump(raw, j):
    nl = b'\r\n' if b'\r\n' in raw else b'\n'
    s = json.dumps(j, ensure_ascii=False, indent=2).encode('utf-8').replace(b'\n', nl)
    return (b'\xef\xbb\xbf' if raw.startswith(b'\xef\xbb\xbf') else b'') + s + (nl if raw.endswith(nl) else b'')


def open_report(path):
    report = os.path.abspath(path.rstrip('\\/'))
    definition = os.path.join(report, 'definition')
    if not os.path.isdir(definition):
        sys.exit(f'Not a PBIR report folder (no definition\\): {report}')
    model = report[:-len('.Report')] + '.SemanticModel' if report.endswith('.Report') else None
    return report, definition, model


def validate(report):
    try:
        r = subprocess.run(['pbir', 'validate', report], capture_output=True, text=True, encoding='utf-8')
        return (r.stdout + r.stderr).strip().splitlines()[-1]
    except Exception as e:
        return f'(pbir not available: {e.__class__.__name__})'


def write(report, changes, backup_dir, label):
    """Backup the report, write {path: bytes}, pbir validate before / after."""
    bdir = backup_dir
    if not bdir:
        up = os.path.dirname(report)
        for _ in range(3):
            if os.path.isdir(os.path.join(up, 'BackUp')):
                bdir = os.path.join(up, 'BackUp')
                break
            up = os.path.dirname(up)
        bdir = bdir or os.path.join(os.path.dirname(report), 'BackUp')
    label = re.sub(r'[<>:"/\\|?*]', '_', label)  # column names like 'SalesVal - Is 0?' are not valid in Windows paths
    dest = os.path.join(bdir, f'{label}_{datetime.now():%Y-%m-%d_%H%M%S}')
    shutil.copytree(report, os.path.join(dest, os.path.basename(report)))
    print(f'Backup: {dest}')
    before = validate(report)
    for p, data in changes.items():
        open(p, 'wb').write(data)
    print(f'pbir validate  before: {before}\n               after:  {validate(report)}')


def parse_field(s, allow_level=True):
    m = re.fullmatch(r"'?([^'\[]+)'?\[([^\]]+)\](?:\[([^\]]+)\])?", s.strip())
    if not m or (m.group(3) and not allow_level):
        sys.exit(f'Bad field "{s}" - use Table[Column]' + (', Table[Hierarchy][Level] or a bare table name' if allow_level else ''))
    return m.group(1), m.group(2), m.group(3)


def page_names(definition):
    pd = os.path.join(definition, 'pages')
    return {p: load(os.path.join(pd, p, 'page.json'))[1].get('displayName', '')
            for p in os.listdir(pd) if os.path.exists(os.path.join(pd, p, 'page.json'))}


# ============================================================ replace
class Replace:
    def __init__(self, a):
        self.a = a
        self.report, self.definition, self.model = open_report(a.report)

    def read_table(self, tbl):
        """{'columns': {name: dataType}, 'levels': {(hierarchy, level): column}} from the TMDL, or None."""
        tmdl = self.model and os.path.join(self.model, 'definition', 'tables', re.sub(r'[<>:"/\|?*%]', lambda c: '%%%02X' % ord(c.group()), tbl) + '.tmdl')  # Desktop %-encodes characters Windows forbids in file names (P&L|X -> P&L%7CX.tmdl)
        if not (tmdl and os.path.exists(tmdl)):
            return None
        text = open(tmdl, encoding='utf-8').read().replace('\r\n', '\n') + '\n\t'
        unq = lambda n: n[1:-1].replace("''", "'") if n.startswith("'") else n
        cols, levels = {}, {}
        for m in re.finditer(r"^\tcolumn ('(?:[^']|'')+'|[^\s=]+)(?: =.*)?\n((?:\t\t.*\n|\n)*?)(?=^\t\S)", text, re.M):
            dt = re.search(r'^\t\tdataType: (\w+)', m.group(2), re.M)
            cols[unq(m.group(1))] = dt.group(1) if dt else None
        for m in re.finditer(r"^\thierarchy ('(?:[^']|'')+'|\S+)\s*\n((?:\t\t.*\n|\n)*?)(?=^\t\S)", text, re.M):
            for lv in re.finditer(r"^\t\tlevel ('(?:[^']|'')+'|\S+)\s*\n(?:\t\t\t.*\n)*?\t\t\tcolumn: (.+?)\s*\n", m.group(2), re.M):
                levels[(unq(m.group(1)), unq(lv.group(1)))] = unq(lv.group(2))
        return {'columns': cols, 'levels': levels}

    def check(self, tbl, name, level, spec, quiet=False):
        """Returns the column behind the field (the level's column for a hierarchy level)."""
        t = self.read_table(tbl)
        if t is None:
            if not quiet:
                print(f'(model table {tbl} not found next to the report - {spec} not checked)')
            return level or name
        if level:
            hit = next(((h, l) for h, l in t['levels'] if h.lower() == name.lower() and l.lower() == level.lower()), None)
            if not hit:
                sys.exit(f'Hierarchy level {spec} not found in table {tbl}')
            return t['levels'][hit]
        hit = next((c for c in t['columns'] if c.lower() == name.lower()), None)
        if not hit:
            sys.exit(f'Column {spec} not found in table {tbl}')
        return hit

    def pairs(self):
        a = self.a
        if '[' in a.src or '[' in a.dst:
            return [(a.src, a.dst)]
        src_t, dst_t = self.read_table(a.src.strip("'")), self.read_table(a.dst.strip("'"))
        if dst_t is None:
            sys.exit(f'Table mode needs {a.dst} in the sibling model')
        self.rename = src_t is None
        if self.rename:   # the old table is already gone / renamed in the model
            print(f'  {a.src} is not in the model - rename mode: every column / level of {a.dst}')
            src_t = dst_t
        skip = {x.strip().lower() for x in (a.skip or '').split(',') if x.strip()}
        dst_cols = {k.lower(): k for k in dst_t['columns']}
        dst_levels = {(h.lower(), l.lower()): (h, l) for h, l in dst_t['levels']}
        out = []
        for (h, l) in src_t['levels']:
            if h.lower() in skip:
                continue
            if (h.lower(), l.lower()) in dst_levels:
                th, tl = dst_levels[(h.lower(), l.lower())]
                out.append((f'{a.src}[{h}][{l}]', f'{a.dst}[{th}][{tl}]'))
            else:
                print(f'  - level {h}.{l}: not in {a.dst}, left as is')
        for c, dt in src_t['columns'].items():
            dt2 = dst_t['columns'].get(dst_cols.get(c.lower()))
            if c.lower() in skip:
                print(f'  - column {c}: --skip')
            elif c.lower() not in dst_cols:
                continue
            elif dt and dt2 and dt != dt2:
                print(f'  - column {c}: dataType {dt} -> {dt2}, skipped')
            else:
                if not (dt and dt2) and not self.rename:
                    print(f'  - column {c}: calculated column (no dataType in TMDL), type not checked - replaced')
                out.append((f'{a.src}[{c}]', f'{a.dst}[{dst_cols[c.lower()]}]'))
        only_src = sorted(c for c in src_t['columns'] if c.lower() not in dst_cols)
        if only_src:
            print(f'  - {len(only_src)} column(s) only in {a.src}, left as is: {", ".join(only_src)}')
        return out

    def use(self, src, dst):
        """Set the fields the matcher works with for one (from, to) pair."""
        self.table, self.old_name, self.old_level = parse_field(src)
        self.new_table, self.new_name, self.new_level = parse_field(dst)
        self.old_ref = f'{self.table}.{self.old_name}' + (f'.{self.old_level}' if self.old_level else '')
        self.new_ref = f'{self.new_table}.{self.new_name}' + (f'.{self.new_level}' if self.new_level else '')
        self.other_table = self.new_table != self.table
        self.level_col = self.check(self.new_table, self.new_name, self.new_level, dst)
        self.old_col = self.check(self.table, self.old_name, self.old_level, src, quiet=self.rename) \
            if self.old_level else self.old_name
        self.ref_re = re.compile(rf'(?<![\w.]){re.escape(self.old_ref)}(?![\w .\-])', re.I)

    def new_field(self, source_ref, as_column=False):
        if as_column or not self.new_level:
            return {'Column': {'Expression': {'SourceRef': source_ref}, 'Property': self.level_col}}
        return {'HierarchyLevel': {'Expression': {'Hierarchy': {'Expression': {'SourceRef': source_ref},
                                                                'Hierarchy': self.new_name}}, 'Level': self.new_level}}

    def is_source(self, sr, aliases):
        return sr.get('Entity', aliases.get(sr.get('Source'))) == self.table

    def target_ref(self, sr, aliases):
        """SourceRef for the new field: the new table directly, or its alias in the enclosing From."""
        if not self.other_table:
            return sr
        if 'Entity' in sr:
            return {**sr, 'Entity': self.new_table}
        aliases['__scope__']['used'] = True
        return {'Source': aliases['__scope__']['alias']}

    @staticmethod
    def sources_used(o):
        if isinstance(o, list):
            return set().union(*map(Replace.sources_used, o)) if o else set()
        if not isinstance(o, dict):
            return set()
        found = {o['Source']} if isinstance(o.get('Source'), str) else set()
        return found.union(*(Replace.sources_used(v) for k, v in o.items() if k != 'From'))

    def fix(self, o, aliases, stats, identity=False):
        """Rewrite references in place; returns the (possibly replaced) object."""
        if isinstance(o, list):
            return [self.fix(x, aliases, stats, identity) for x in o]
        if not isinstance(o, dict):
            if isinstance(o, str) and self.ref_re.search(o):
                stats['refs'] += 1
                return self.ref_re.sub(self.new_ref, o)
            return o
        scope = None
        if isinstance(o.get('From'), list):
            aliases = {**aliases, **{f['Name']: f.get('Entity') for f in o['From'] if 'Name' in f}}
            if self.other_table:
                names = {f.get('Name') for f in o['From']}
                alias = next((f['Name'] for f in o['From'] if f.get('Entity') == self.new_table), None)
                if not alias:
                    alias, i = self.new_table[0].lower(), 1
                    while alias in names:
                        alias, i = f'{self.new_table[0].lower()}{i}', i + 1
                scope = {'alias': alias, 'used': False}
                aliases['__scope__'] = scope
        c = o.get('Column')
        if isinstance(c, dict) and str(c.get('Property')).lower() == self.old_col.lower():
            sr = c.get('Expression', {}).get('SourceRef', {})
            if self.is_source(sr, aliases):
                stats['fields'] += 1
                rest = {k: v for k, v in o.items() if k != 'Column'}
                # the column behind a --from level stays a column (identityKeys, saved selection)
                return {**self.new_field(self.target_ref(sr, aliases), identity or bool(self.old_level)),
                        **self.fix(rest, aliases, stats, identity)}
        h = o.get('HierarchyLevel') if self.old_level else None
        if isinstance(h, dict) and str(h.get('Level')).lower() == self.old_level.lower():
            hh = h.get('Expression', {}).get('Hierarchy', {})
            sr = hh.get('Expression', {}).get('SourceRef', {})
            if str(hh.get('Hierarchy')).lower() == self.old_name.lower() and self.is_source(sr, aliases):
                stats['fields'] += 1
                rest = {k: v for k, v in o.items() if k != 'HierarchyLevel'}
                return {**self.new_field(self.target_ref(sr, aliases), identity), **self.fix(rest, aliases, stats, identity)}
        out = {}
        fields_before = stats['fields']
        for k, v in o.items():
            out[k] = self.fix(v, aliases, stats, identity or k == 'identityKeys')
        # nativeQueryRef = the display name of THIS projection's field: rename only when that field was
        # replaced here and the name really changes
        nq = self.new_level or self.new_name
        if (out.get('nativeQueryRef') == self.old_col and nq != self.old_col and not self.old_level
                and 'field' in out and stats['fields'] > fields_before):
            out['nativeQueryRef'] = nq
            stats['refs'] += 1
        if scope and scope['used']:
            if scope['alias'] not in {f.get('Name') for f in out['From']}:
                out['From'] = out['From'] + [{'Name': scope['alias'], 'Entity': self.new_table, 'Type': 0}]
            used = self.sources_used(out)
            out['From'] = [f for f in out['From'] if f.get('Name') in used]
        return out

    def run(self):
        a, definition = self.a, self.definition
        self.rename = False
        pairs = self.pairs()
        only_vis = set(a.visuals.split(',')) if a.visuals else None
        scoped = bool(only_vis or a.visual_type)
        # --- load the documents in scope once; every pair is applied to them in memory ---
        docs, visual_names = {}, set()   # path -> [raw bytes, json, kind]
        for dirpath, _, files in os.walk(os.path.join(definition, 'pages')):
            for f in files:
                p = os.path.join(dirpath, f)
                if f == 'visual.json':
                    raw, j = load(p)
                    vt = j.get('visual', {}).get('visualType')
                    if (only_vis and j.get('name') not in only_vis) or (a.visual_type and vt != a.visual_type):
                        continue
                    visual_names.add(j.get('name'))
                    docs[p] = [raw, j, 'visual']
                elif f == 'page.json' and not scoped:
                    docs[p] = [*load(p), 'page']
        if not scoped:
            p = os.path.join(definition, 'report.json')
            docs[p] = [*load(p), 'report']
        if not a.no_bookmarks:
            bdir = os.path.join(definition, 'bookmarks')
            for f in sorted(os.listdir(bdir)) if os.path.isdir(bdir) else []:
                if f.endswith('.bookmark.json'):
                    docs[os.path.join(bdir, f)] = [*load(os.path.join(bdir, f)), 'bookmark']

        stats, per_pair, dupes = {}, [], []
        for src, dst in pairs:
            self.use(src, dst)
            n_files = 0
            for p, d in docs.items():
                st = {'fields': 0, 'refs': 0}
                if d[2] == 'bookmark' and scoped:   # only the states of the selected visuals
                    for sec in d[1].get('explorationState', {}).get('sections', {}).values():
                        for n, vc in sec.get('visualContainers', {}).items():
                            if n in visual_names:
                                sec['visualContainers'][n] = self.fix(vc, {}, st)
                else:
                    d[1] = self.fix(d[1], {}, st)
                if st['fields'] or st['refs']:
                    n_files += 1
                    total = stats.setdefault(p, {'fields': 0, 'refs': 0})
                    total['fields'] += st['fields']
                    total['refs'] += st['refs']
                    for role in d[1].get('visual', {}).get('query', {}).get('queryState', {}).values():
                        refs = [x.get('queryRef') for x in role.get('projections', [])]
                        if refs.count(self.new_ref) > 1:
                            dupes.append(f'{self.new_ref}: {os.path.relpath(p, definition)}')
            per_pair.append((src, dst, n_files))
        changes = {p: dump(docs[p][0], docs[p][1]) for p in stats}

        print(f'{a.src} -> {a.dst}  ({"APPLY" if a.apply else "dry run"})')
        if len(pairs) > 1:
            for src, dst, n in per_pair:
                if n:
                    print(f'  {n:3} files  {src} -> {dst}')
        for p, st in sorted(stats.items()):
            print(f"  {st['fields']:3} fields {st['refs']:3} refs  {os.path.relpath(p, definition)}")
        print(f'TOTAL files: {len(changes)}')
        for d in dupes:
            print(f'  !! now appears twice in one visual - remove one projection by hand: {d}')
        if not a.apply:
            return
        if changes:
            label = (parse_field(a.src)[2] or parse_field(a.src)[1]) if len(pairs) == 1 and '[' in a.src else a.src.strip("'")
            write(self.report, changes, a.backup_dir, f'ReplaceField_{label}')

        # --- leftovers anywhere in the report ---
        note = ' (run was limited by --visuals / --visual-type, so others are expected)' if scoped else ''
        files = [os.path.join(d, f) for d, _, fs in os.walk(definition) for f in fs if f.endswith('.json')]
        docs_now = {p: load(p)[1] for p in files}
        for src, dst in pairs:
            self.use(src, dst)
            left = []
            for p, j in docs_now.items():
                st = {'fields': 0, 'refs': 0}
                self.fix(j, {}, st)
                if st['fields'] or st['refs']:
                    left.append(os.path.relpath(p, definition))
            if left or len(pairs) == 1:
                print(f'Still referencing {src}: {len(left)} file(s){note}' + ('' if not left else ':\n  ' + '\n  '.join(left)))


# ============================================================ drop-filters
def drop_filters(a):
    report, definition, _ = open_report(a.report)
    fields = [parse_field(f, allow_level=False)[:2] for f in a.field]
    fields_l = {(t, c.lower()) for t, c in fields}

    def uses(o, aliases=None):
        """True when o references one of the fields (SourceRef by Entity or by a From alias)."""
        aliases = dict(aliases or {})
        if isinstance(o, list):
            return any(uses(x, aliases) for x in o)
        if not isinstance(o, dict):
            return False
        if isinstance(o.get('From'), list):
            aliases.update({f['Name']: f.get('Entity') for f in o['From'] if 'Name' in f})
        c = o.get('Column')
        if isinstance(c, dict):
            sr = c.get('Expression', {}).get('SourceRef', {})
            if (sr.get('Entity') or aliases.get(sr.get('Source')), str(c.get('Property')).lower()) in fields_l:
                return True
        return any(uses(v, aliases) for v in o.values())

    def literals(o):
        if isinstance(o, dict):
            return ([o['Literal']['Value'].strip("'")] if 'Literal' in o else []) + [x for v in o.values() for x in literals(v)]
        return [x for v in o for x in literals(v)] if isinstance(o, list) else []

    pages_dir = os.path.join(definition, 'pages')
    names = page_names(definition)

    def visual_label(page, vis):
        p = os.path.join(pages_dir, page, 'visuals', vis, 'visual.json')
        if not os.path.exists(p):
            return ''
        v = load(p)[1].get('visual', {})
        try:
            title = v['visualContainerObjects']['title'][0]['properties']['text']['expr']['Literal']['Value'].strip("'")
        except (KeyError, IndexError, TypeError):
            title = ''
        return v.get('visualType', '') + (f' — {title}' if title else '')

    rows, changes, still_used = [], {}, []
    for dirpath, _, files in os.walk(definition):
        for f in files:
            if not f.endswith('.json'):
                continue
            p = os.path.join(dirpath, f)
            rel = os.path.relpath(p, definition).replace('\\', '/')
            raw, doc = load(p)
            parts = rel.split('/')
            page = parts[1] if parts[0] == 'pages' and len(parts) > 2 else ''
            visual = parts[3] if len(parts) > 4 and parts[2] == 'visuals' else ''
            holders = []   # (container, key, bookmark, page, visual)
            if 'filterConfig' in doc:
                holders.append((doc['filterConfig'], 'filters', '', page, visual))
            es = doc.get('explorationState')
            if es:
                bm = doc.get('displayName', '')
                holders += [(es['filters'], k, bm, '', '') for k in ('byExpr', 'byName') if k in es.get('filters', {})]
                for sec, s in es.get('sections', {}).items():
                    holders += [(s['filters'], k, bm, sec, '') for k in ('byExpr', 'byName') if k in s.get('filters', {})]
                    for vc, v in s.get('visualContainers', {}).items():
                        holders += [(v['filters'], k, bm, sec, vc) for k in ('byExpr', 'byName') if k in v.get('filters', {})]
            changed = False
            for obj, key, bm, pg, vis in holders:
                lst = obj[key]
                items = list(lst.items()) if isinstance(lst, dict) else list(enumerate(lst))
                drop = [k for k, flt in items if uses(flt)]
                for k, flt in items:
                    if k in drop:
                        cond = flt.get('filter') or flt.get('expression') or flt
                        vals = ', '.join(literals(cond)) or '(empty — no condition)'
                        rows.append({'bookmark': bm, 'page': pg, 'visual': vis,
                                     'values': ('NOT ' if '"Not"' in json.dumps(cond) else '') + vals})
                if drop:
                    obj[key] = {k: v for k, v in lst.items() if k not in drop} if isinstance(lst, dict) \
                        else [v for i, v in enumerate(lst) if i not in drop]
                    changed = True
            if changed:
                changes[p] = dump(raw, doc)
            if uses(doc):
                still_used.append(rel)

    key = lambda r: (int(re.sub(r'\D', '', r['page']) or 0), r['visual'])
    md = [f"Dropped filters on {', '.join(a.field)} ({len(rows)})", '',
          '### Visual and page filters', '', '| Page | Visual | Type / title | Kept values |', '|---|---|---|---|']
    for r in sorted((r for r in rows if not r['bookmark']), key=key):
        lbl = visual_label(r['page'], r['visual']) if r['visual'] else 'page filter' if r['page'] else 'report filter'
        md.append(f"| {r['page']} {names.get(r['page'], '')} | {r['visual'] or '—'} | {lbl} | {r['values']} |")
    md += ['', '### Bookmark filter states', '', '| Bookmark | Page | Visual | Kept values |', '|---|---|---|---|']
    for r in sorted((r for r in rows if r['bookmark']), key=key):
        md.append(f"| {r['bookmark']} | {r['page']} {names.get(r['page'], '')} | {r['visual'] or '(page level)'} | {r['values']} |")
    text = '\n'.join(md) + '\n'
    if a.list:
        open(a.list, 'w', encoding='utf-8', newline='\n').write(text)
        print(f'List: {a.list}')
    else:
        print(text)
    print(f"{len(rows)} filter(s) in {len(changes)} file(s) ({'APPLY' if a.apply else 'dry run'})")
    if still_used:
        print('Still used outside filters (left as is - decide by hand):\n  ' + '\n  '.join(still_used))
    if a.apply and changes:
        write(report, changes, a.backup_dir, f'DropFilters_{fields[0][1]}')


# ============================================================ clean-filters
def clean_filters(a):
    report, definition, _ = open_report(a.report)
    only_pages = set(a.pages.split(',')) if a.pages else None

    def sigs(field):
        """Comparable keys of a field: column/measure by (entity, name); a hierarchy level also by its level name."""
        out = set()

        def walk(o):
            if isinstance(o, dict):
                for kind in ('Column', 'Measure'):
                    x = o.get(kind)
                    if isinstance(x, dict) and 'Property' in x:
                        out.add((x.get('Expression', {}).get('SourceRef', {}).get('Entity'), x['Property']))
                hl = o.get('HierarchyLevel')
                if isinstance(hl, dict):
                    h = hl.get('Expression', {}).get('Hierarchy', {})
                    ent = h.get('Expression', {}).get('SourceRef', {}).get('Entity')
                    out.add((ent, f"{h.get('Hierarchy')}.{hl.get('Level')}"))
                    out.add((ent, hl.get('Level')))   # level name = its column in our models
                for v in o.values():
                    walk(v)
            elif isinstance(o, list):
                for v in o:
                    walk(v)
        walk(field)
        return out

    def label(f):
        s = sorted(sigs(f.get('field', {})))
        return f"{s[0][0]}[{s[0][1]}]" if s else json.dumps(f.get('field'), ensure_ascii=False)[:60]

    changes, removed = {}, {}   # path -> new bytes ; page -> set of removed page-card names
    rows, skipped, report_level = [], [], []

    # bookmarks: page cards that some bookmark gives a condition to (= used)
    bookmarks = {p: load(p) for p in glob.glob(os.path.join(definition, 'bookmarks', '*.bookmark.json'))}
    cond_in_bm = set()   # (page, filter name)
    for _, (raw, j) in bookmarks.items():
        for pg, sec in j.get('explorationState', {}).get('sections', {}).items():
            for kind in ('byName', 'byExpr'):
                fl = sec.get('filters', {}).get(kind, {})
                items = fl.items() if isinstance(fl, dict) else [(x.get('name'), x) for x in fl]
                for n, x in items:
                    if isinstance(x, dict) and 'filter' in x:
                        cond_in_bm.add((pg, n or x.get('name')))

    for pdir in sorted(glob.glob(os.path.join(definition, 'pages', '*'))):
        pg = os.path.basename(pdir)
        if not os.path.isdir(pdir) or (only_pages and pg not in only_pages):
            continue
        pj = os.path.join(pdir, 'page.json')
        raw, j = load(pj)
        pname = j.get('displayName', pg).strip()
        if not a.no_pages:
            fl = j.get('filterConfig', {}).get('filters', [])
            drop = [f for f in fl if 'filter' not in f and (pg, f.get('name')) not in cond_in_bm]
            if drop:
                if dump(raw, j) != raw:
                    skipped.append(pj)
                else:
                    j['filterConfig']['filters'] = [f for f in fl if f not in drop]
                    changes[pj] = dump(raw, j)
                    removed[pg] = {f.get('name') for f in drop}
                    rows += [(pname, 'page', '', label(f)) for f in drop]
        if a.no_visuals:
            continue
        for vp in sorted(glob.glob(os.path.join(pdir, 'visuals', '*', 'visual.json'))):
            raw, j = load(vp)
            fl = j.get('filterConfig', {}).get('filters', [])
            if not fl:
                continue
            used = sigs(j.get('visual', {}).get('query', {}))
            drop = [f for f in fl if 'filter' not in f and not (sigs(f.get('field', {})) & used)]
            if not drop:
                continue
            if dump(raw, j) != raw:
                skipped.append(vp)
                continue
            j['filterConfig']['filters'] = [f for f in fl if f not in drop]
            if not j['filterConfig']['filters']:
                del j['filterConfig']
            changes[vp] = dump(raw, j)
            rows += [(pname, 'visual', j.get('name'), label(f)) for f in drop]

    # bookmark entries for removed page cards (no condition)
    for bp, (raw, j) in bookmarks.items():
        n = 0
        for pg, sec in j.get('explorationState', {}).get('sections', {}).items():
            gone = removed.get(pg)
            if not gone:
                continue
            flt = sec.get('filters', {})
            for kind in ('byName', 'byExpr'):
                fl = flt.get(kind)
                if isinstance(fl, dict):
                    for k in [k for k, x in fl.items() if k in gone and 'filter' not in x]:
                        del fl[k]
                        n += 1
                elif isinstance(fl, list):
                    keep = [x for x in fl if not (x.get('name') in gone and 'filter' not in x)]
                    n += len(fl) - len(keep)
                    flt[kind] = keep
        if n:
            if dump(raw, json.loads(raw.decode('utf-8-sig'))) != raw:
                skipped.append(bp)
            else:
                changes[bp] = dump(raw, j)
                rows.append(('(bookmark)', 'bookmark', j.get('displayName', ''), f'{n} state(s) of removed page cards'))

    # report level: list only; an empty page card is a tool for viewers when they see the Filters pane
    rp = os.path.join(definition, 'report.json')
    pane_visible = True
    if os.path.exists(rp):
        rj = load(rp)[1]
        report_level = [label(f) for f in rj.get('filterConfig', {}).get('filters', []) if 'filter' not in f]
        for o in rj.get('objects', {}).get('outspacePane', []):
            if o.get('properties', {}).get('visible', {}).get('expr', {}).get('Literal', {}).get('Value') == 'false':
                pane_visible = False
    if pane_visible and any(r[1] == 'page' for r in rows):
        print('!! The Filters pane is VISIBLE to viewers: empty page cards may be meant for them - review before --apply.')

    print(f'{"APPLY" if a.apply else "dry run"}: {sum(1 for r in rows if r[1] != "bookmark")} card(s) in {len(changes)} file(s)'
          f'  (Filters pane for viewers: {"visible" if pane_visible else "hidden"})')
    for pname, lvl, vis, fld in rows:
        print(f'  {lvl:8} {pname[:32]:32} {vis or "":22} {fld}')
    if report_level:
        print(f'Report level (not touched), cards without a condition: {", ".join(report_level)}')
    for s in skipped:
        print(f'  !! skipped (format would change): {os.path.relpath(s, definition)}')
    if a.apply and changes:
        write(report, changes, a.backup_dir, 'CleanReportFilters')


# ============================================================ refs
def refs(a):
    """Count report references per column / hierarchy level of one table (all JSON incl. bookmarks)."""
    _, definition, _ = open_report(a.report)
    count, files = {}, {}

    def walk(o, aliases, path):
        if isinstance(o, list):
            for x in o:
                walk(x, aliases, path)
            return
        if not isinstance(o, dict):
            return
        if isinstance(o.get('From'), list):
            aliases = {**aliases, **{f['Name']: f.get('Entity') for f in o['From'] if 'Name' in f}}
        for kind in ('Column', 'Measure'):
            c = o.get(kind)
            if isinstance(c, dict) and 'Property' in c:
                sr = c.get('Expression', {}).get('SourceRef', {})
                if (sr.get('Entity') or aliases.get(sr.get('Source'))) == a.table:
                    k = c['Property'] if kind == 'Column' else f"[measure] {c['Property']}"
                    count[k] = count.get(k, 0) + 1
                    files.setdefault(k, set()).add(path)
        h = o.get('HierarchyLevel')
        if isinstance(h, dict):
            hh = h.get('Expression', {}).get('Hierarchy', {})
            sr = hh.get('Expression', {}).get('SourceRef', {})
            if (sr.get('Entity') or aliases.get(sr.get('Source'))) == a.table:
                k = f"{hh.get('Hierarchy')}.{h.get('Level')}"
                count[k] = count.get(k, 0) + 1
                files.setdefault(k, set()).add(path)
        for v in o.values():
            walk(v, aliases, path)

    for d, _, fs in os.walk(definition):
        for f in fs:
            if f.endswith('.json'):
                p = os.path.join(d, f)
                walk(load(p)[1], {}, os.path.relpath(p, definition))
    for k in sorted(count, key=str.lower):
        print(f'{count[k]:5} refs {len(files[k]):4} files  {k}')
    print(f'TOTAL {sum(count.values())} reference(s) to {a.table}')


# ============================================================ CLI
ap = argparse.ArgumentParser(description='PBIR report fields and filters')
sub = ap.add_subparsers(dest='cmd', required=True)
p = sub.add_parser('replace', help='replace a column / level / whole table everywhere in the report')
p.add_argument('report')
p.add_argument('--from', dest='src', required=True)
p.add_argument('--to', dest='dst', required=True)
p.add_argument('--visual-type')
p.add_argument('--visuals')
p.add_argument('--no-bookmarks', action='store_true')
p.add_argument('--skip')
p = sub.add_parser('drop-filters', help='drop every filter on a column, list them as Markdown')
p.add_argument('report')
p.add_argument('--field', action='append', required=True)
p.add_argument('--list')
p = sub.add_parser('clean-filters', help='remove Filters-pane cards that filter nothing and are not used')
p.add_argument('report')
p.add_argument('--pages')
p.add_argument('--no-visuals', action='store_true')
p.add_argument('--no-pages', action='store_true')
for p in sub.choices.values():
    p.add_argument('--apply', action='store_true')
    p.add_argument('--backup-dir')
p = sub.add_parser('refs', help='count report references per column of a table (read-only)')
p.add_argument('report')
p.add_argument('--table', required=True)
args = ap.parse_args()
{'replace': lambda a: Replace(a).run(), 'drop-filters': drop_filters, 'clean-filters': clean_filters,
 'refs': refs}[args.cmd](args)
