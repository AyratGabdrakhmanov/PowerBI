"""Trim a project's Calendar to the columns it uses, keeping the FULL reference DAX (Refactoring.md step 1a, user 2026-10-26).

Every Calendar column is optional except the hierarchy level columns and `Closed Period`. The partition keeps the whole
reference expression; the column definitions nobody uses are commented out (`-- `) inside ADDCOLUMNS, and their column
objects are removed from Calendar.tmdl. Re-enabling a column = uncomment its lines + add the column back.

Used = referenced in DAX (any other table / measure / calc column / calc table), in the report (Entity or From alias,
incl. saved filters and bookmarks), by a relationship, as sort-by of a kept column, as a hierarchy level, or kept always
(Closed Period). Dry run by default; --apply writes Calendar.tmdl (backup next to the project in BackUp\\TrimCalendar_<ts>).

    python -I -X utf8 TrimCalendar.py "<project folder with X.SemanticModel / X.Report>" [--apply]
SCRIPT_VERSION: 2026-10-26.1
"""
import datetime, glob, io, json, os, re, shutil, sys

ALWAYS = {'Date', 'Closed Period'}
proj = sys.argv[1]; APPLY = '--apply' in sys.argv
sm = glob.glob(os.path.join(proj, '*.SemanticModel'))[0]; rp = glob.glob(os.path.join(proj, '*.Report'))[0]
tdir = os.path.join(sm, 'definition', 'tables'); cal_path = os.path.join(tdir, 'Calendar.tmdl')
cal = io.open(cal_path, encoding='utf-8', newline='').read()

# --- Calendar structure -------------------------------------------------------------------------------------------
col_blocks = list(re.finditer(r"^\tcolumn ('(?:[^']|'')+'|[^\s=]+)[^\n]*\n(?:(?:\t\t[^\n]*|\s*)\n)*?(?=^\t\S)", cal, re.M))
cols = {m.group(1).strip("'").replace("''", "'"): m for m in col_blocks}
sort_by = {n: re.search(r"^\t\tsortByColumn: ('(?:[^']|'')+'|\S+)", m.group(0), re.M) for n, m in cols.items()}
sort_by = {n: s.group(1).strip("'") for n, s in sort_by.items() if s}
levels = set(c.strip("'") for c in re.findall(r"^\t\t\tcolumn: ('(?:[^']|'')+'|\S+)", cal, re.M))

# --- usage --------------------------------------------------------------------------------------------------------
used = set(ALWAYS) | levels
for f in glob.glob(os.path.join(tdir, '*.tmdl')):
    if os.path.basename(f) == 'Calendar.tmdl': continue
    t = re.sub(r'/\*.*?\*/|//[^\n]*|--[^\n]*', '', io.open(f, encoding='utf-8').read(), flags=re.S)
    used |= {a or b for a, b in re.findall(r"'Calendar'\[([^\]]+)\]|(?<![\w'])Calendar\[([^\]]+)\]", t)}
rel = io.open(os.path.join(sm, 'definition', 'relationships.tmdl'), encoding='utf-8').read()
used |= set(c.strip("'") for c in re.findall(r"Column: Calendar\.('(?:[^']|'')+'|\S+)", rel))


def walk(o, al):
    if isinstance(o, dict):
        if isinstance(o.get('From'), list):
            al = dict(al); al.update({x['Name']: x['Entity'] for x in o['From'] if isinstance(x, dict) and 'Entity' in x})
        for key in ('Column', 'Hierarchy'):
            c = o.get(key)
            if isinstance(c, dict):
                sr = c.get('Expression', {}).get('SourceRef', {})
                if (sr.get('Entity') or al.get(sr.get('Source'))) == 'Calendar':
                    used.add(c.get('Property') if key == 'Column' else '__H__' + str(c.get('Hierarchy')))
        for v in o.values(): walk(v, al)
    elif isinstance(o, list):
        for v in o: walk(v, al)


for f in glob.glob(os.path.join(rp, 'definition', '**', '*.json'), recursive=True):
    walk(json.load(io.open(f, encoding='utf-8')), {})
changed = True
while changed:                                   # sort-by targets of kept columns
    n = len(used); used |= {sort_by[c] for c in list(used) if c in sort_by}; changed = len(used) != n
unused = [c for c in cols if c not in used]

# --- expression: comment the ADDCOLUMNS entries of unused columns --------------------------------------------------
lines = cal.split('\n')
starts = [(i, re.match(r'^(\s*), "([^"]+)",', l)) for i, l in enumerate(lines)]
starts = [(i, m.group(2)) for i, m in starts if m]
out = list(lines); commented = []
for k, (i, name) in enumerate(starts):
    end = starts[k + 1][0] if k + 1 < len(starts) else None
    if end is None:                             # last entry: until the line that closes ADDCOLUMNS
        end = i + 1
        while end < len(lines) and not re.match(r'^\s*\)\s*$', lines[end]): end += 1
    while end - 1 > i and not lines[end - 1].strip(): end -= 1     # keep trailing blank lines as they are
    if name in unused:
        for j in range(i, end):
            if lines[j].strip() and not lines[j].lstrip().startswith('-- '):
                ind = len(lines[j]) - len(lines[j].lstrip())
                out[j] = lines[j][:ind] + '-- ' + lines[j][ind:]
        commented.append(name)
missing = [c for c in unused if c not in commented]
if missing: sys.exit('no ADDCOLUMNS entry found for: %s - nothing written' % missing)

new = '\n'.join(out)
for c in sorted(unused, key=lambda c: -cols[c].start()):        # remove column objects (from the end)
    m = re.search(r"^\tcolumn " + re.escape(cols[c].group(1)) + r"[^\n]*\n(?:(?:\t\t[^\n]*|\s*)\n)*?(?=^\t\S)", new, re.M)
    new = new[:m.start()] + new[m.end():]

print('Calendar columns: %d   kept: %d   commented out: %d' % (len(cols), len(cols) - len(unused), len(unused)))
print('kept:', ', '.join(c for c in cols if c not in unused))
print('commented out:', ', '.join(unused) or '-')
bak = os.path.join(os.path.dirname(proj), 'BackUp', 'TrimCalendar_' + datetime.datetime.now().strftime('%Y-%m-%d_%H%M%S'))
if APPLY and unused:
    os.makedirs(bak, exist_ok=True); shutil.copy2(cal_path, bak)
    io.open(cal_path, 'w', encoding='utf-8', newline='').write(new)
    print('written; backup', bak)

# --- culture translations of Calendar columns that no longer exist (a dangling one blocks the model load) ----------
final_cols = set(c.strip("'").replace("''", "'") for c in re.findall(r"^\tcolumn ('(?:[^']|'')+'|[^\s=]+)",
                 io.open(cal_path, encoding='utf-8').read() if APPLY else new, re.M))
for cf in glob.glob(os.path.join(sm, 'definition', 'cultures', '*.tmdl')):
    raw = io.open(cf, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in raw else '\n'
    ls = raw.split(nl); keep = []; i = 0; in_cal = False; dropped = []
    while i < len(ls):
        l = ls[i]
        if re.match(r'^\t\t\ttable ', l): in_cal = (l.strip() == 'table Calendar')
        elif not l.startswith('\t\t\t\t') and l.strip(): in_cal = False
        m = re.match(r"^\t\t\t\tcolumn ('(?:[^']|'')+'|\S+)\s*$", l) if in_cal else None
        if m and m.group(1).strip("'").replace("''", "'") not in final_cols:
            dropped.append(m.group(1)); i += 1
            while i < len(ls) and (ls[i].startswith('\t\t\t\t\t') or not ls[i].strip()) and not re.match(r'^\t{0,4}\S', ls[i]):
                i += 1
            continue
        keep.append(l); i += 1
    if dropped:
        print('%s: %d dangling Calendar translation(s)%s' % (os.path.basename(cf), len(dropped), ' removed' if APPLY else ''))
        if APPLY:
            os.makedirs(bak, exist_ok=True); shutil.copy2(cf, bak)
            io.open(cf, 'w', encoding='utf-8', newline='').write(nl.join(keep))
