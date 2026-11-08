r"""ReportMap.py - map of a PBIP report for review: page groups (purpose), pages, page / visual filters, slicers with
their saved default values, visual titles (He / En from title measures), consistency flags per page group.

Usage (Python with openpyxl, not -I):
    python ReportMap.py "<project folder with the .pbip>" "<out.xlsx>" ["<config.json>"]
Config (optional, keep it in the project folder - client page names stay out of the ClientA repo):
    {"groups": [{"group": "1 Dashboards", "purpose": "...", "pages": {"<tab name>": "<English name>"}}],
     "values_en": {"<Hebrew value>": "<English>"}, "fields_en": {"<Table.Column>": "<English>"}}
Pages not in the config go to group "? (not grouped)". Consistency: within a group the most common value of each
setting (month / document type / agent slicer defaults, page filters) is the norm; page filters are compared by
presence + hidden / locked only (their values differ by design). Sheets: Groups, Pages, Slicers, Visuals, Consistency.

Optional config parts: "allocations": [{"concept", "rule", "source", "fields": ["Table.Column", ...], "notes"}] ->
sheet Allocation (usage per field computed from the report); "model_tables": ["<DAX DATATABLE table>", ...] -> one
"Data <table>" sheet each (rows parsed from the TMDL); an item can be an object {"table", "lookup": {"file", "sheet",
"key", "model_key", "columns", "label"}, "highlight_blank": ["<column>"]} - extra columns from an xlsx matched on a key,
rows with a blank column in yellow; "notes": ["..."] -> sheet Notes.

Config "headers_en": {"<Hebrew header text>": "<English>"} -> Pages "Header text (En)" (a page-title card gives it from its measure).
Reviewer comments: Pages "Comments" column is carried over from the existing output file by page id.

Change log:
  2026-11-05  blank separator pages (Sep10 …) skipped
  2026-11-05  Header text (En) column, page-title card header, Comments carried over, flags as plain sentences
  2026-11-05  fix: freeze panes set once per sheet (Notes view was repaired by Excel)
  2026-11-05  fix: values starting with "=" (e.g. slicer default "= 6") were written as formulas - Excel "repair" prompt
  2026-11-05  model table lookup columns from xlsx, blank-row highlight, Notes sheet
  2026-11-05  Allocation + Data sheets (config "allocations", "model_tables")
  2026-11-05  created (ClientC Sales NEW review; config ClientC\Sales New\ReportMap_config.json)
"""
import json, sys, os, glob, re
from collections import Counter, defaultdict
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.utils import get_column_letter
sys.stdout.reconfigure(encoding='utf-8')
root, out = sys.argv[1], sys.argv[2]
cfg = json.load(open(sys.argv[3], encoding='utf-8')) if len(sys.argv) > 3 else {}
pbip = glob.glob(os.path.join(root, '*.pbip'))
assert len(pbip) == 1, 'expected one .pbip in ' + root
stem = os.path.splitext(os.path.basename(pbip[0]))[0]
rep = os.path.join(root, stem + '.Report'); base = os.path.join(rep, 'definition', 'pages')
mt = ''.join(open(f, encoding='utf-8').read() for f in glob.glob(os.path.join(root, stem + '.SemanticModel', 'definition', 'tables', '*.tmdl')))
order = json.load(open(os.path.join(base, 'pages.json'), encoding='utf-8'))['pageOrder']

G = {}; EN = {}; PURPOSE = {}
for gr in cfg.get('groups', []):
    PURPOSE[gr['group']] = gr.get('purpose', '')
    for he, en in gr.get('pages', {}).items(): G[he] = gr['group']; EN[he] = en
VAL_EN = cfg.get('values_en', {}); FIELD_EN = cfg.get('fields_en', {}); HEAD_EN = cfg.get('headers_en', {})
def tr(v):
    v = str(v); return '%s (%s)' % (v, VAL_EN[v]) if v in VAL_EN else v
def has_he(s): return bool(re.search(r'[֐-׿]', s or ''))

# ---------- helpers ----------
def field_name(fld):
    for k in ('Column', 'Measure', 'Aggregation', 'HierarchyLevel'):
        if k in fld:
            x = fld[k]
            if k == 'Aggregation': x = x['Expression']['Column']
            if k == 'HierarchyLevel':
                h = x['Expression']['Hierarchy']; return '%s[%s / %s]' % (h['Expression']['SourceRef'].get('Entity'), h['Hierarchy'], x['Level'])
            return '%s[%s]' % (x['Expression']['SourceRef'].get('Entity') or x['Expression']['SourceRef'].get('Source'), x['Property'])
    return '?'
def cond_text(where):
    if not where: return '(All)'
    s = json.dumps(where, ensure_ascii=False)
    vals = re.findall(r'"Value": "([^"]+)"', s)
    clean = [v.strip("'").replace("datetime'", '').replace('T00:00:00', '').rstrip("'") for v in vals]
    clean = [c[:-1] if re.fullmatch(r'-?\d+[LDM]', c) else c for c in clean]
    neg = '"Not"' in s
    if '"Comparison"' in s and '"And"' in s and len(clean) == 2: return 'between %s and %s' % (clean[0], clean[1])
    if '"Comparison"' in s:
        kind = {'0': '=', '1': '>', '2': '>=', '3': '<', '4': '<='}.get((re.findall(r'"ComparisonKind": (\d)', s) or ['0'])[0], '?')
        return ('%s %s %s' % ('not' if neg else '', kind, ', '.join(clean))).strip()
    if '"IsNull"' in s or (not clean and neg): return 'is not blank' if neg else 'is blank'
    txt = ', '.join(tr(c) for c in clean[:12]) + (' … (%d values)' % len(clean) if len(clean) > 12 else '')
    return ('NOT ' if neg else '') + txt if clean else s[:120]
def filters_text(flist, mark_flags=True):
    out = []
    for x in flist:
        if not x.get('filter'): continue
        t = '%s: %s' % (field_name(x.get('field', {})), cond_text(x['filter'].get('Where')))
        if mark_flags and (x.get('isHiddenInViewMode') or x.get('isLockedInViewMode')):
            t += ' [%s]' % '+'.join(k for k, f in (('hidden', 'isHiddenInViewMode'), ('locked', 'isLockedInViewMode')) if x.get(f))
        out.append(t)
    return out
def measure_texts(m):
    mm = re.search(r"measure '?%s'? =(.*?)(?:\n\t\t(?:isHidden|displayFolder|formatString|lineageTag))" % re.escape(m), mt, re.S)
    if not mm: return '', ''
    lits = re.findall(r'"([^"]*)"', mm.group(1)); lits = [l for l in lits if l not in ('he-IL', 'en-US')]
    he = next((l for l in lits if has_he(l)), ''); en = next((l for l in reversed(lits) if l and not has_he(l)), '')
    return he, en
def title_of(v):
    t = v.get('visual', {}).get('visualContainerObjects', {}).get('title', [{}])[0].get('properties', {})
    shown = t.get('show', {}).get('expr', {}).get('Literal', {}).get('Value') != 'false'
    e = t.get('text', {}).get('expr', {})
    if 'Measure' in e:
        he, en = measure_texts(e['Measure']['Property']); return shown, he, en, '[%s]' % e['Measure']['Property']
    lit = e.get('Literal', {}).get('Value', '').strip("'")
    return shown, (lit if has_he(lit) else ''), ('' if has_he(lit) else lit), 'literal' if lit else ''

DATA = {'tableEx', 'pivotTable', 'card', 'cardVisual', 'kpi', 'gauge', 'barChart', 'clusteredBarChart', 'clusteredColumnChart',
        'lineChart', 'areaChart', 'stackedAreaChart', 'funnel', 'scatterChart', 'donutChart', 'pieChart', 'multiRowCard', 'waterfallChart'}
pages_rows, slicer_rows, visual_rows = [], [], []
cons = defaultdict(dict)
vis_index = 0
for p in order:
    pj = json.load(open(os.path.join(base, p, 'page.json'), encoding='utf-8'))
    name = pj['displayName']
    ptype = 'Tooltip' if (pj.get('type') == 'Tooltip' or p.startswith('TT')) else ('Drill-through' if pj.get('pageBinding', {}).get('type') == 'Drillthrough' else 'Report page')
    if ptype == 'Tooltip': continue
    if p.startswith('Sep') and not glob.glob(os.path.join(base, p, 'visuals', '*')): continue   # blank separator pages (10, 20, ...)
    hidden = pj.get('visibility') == 'HiddenInViewMode'
    if not hidden: vis_index += 1
    grp = G.get(name, '? (not grouped)')
    pfl = filters_text(pj.get('filterConfig', {}).get('filters', []))
    header = []; header_en = []; slicers = []; datav = []
    for f in sorted(glob.glob(os.path.join(base, p, 'visuals', '*', 'visual.json'))):
        v = json.load(open(f, encoding='utf-8')); vis = v.get('visual', {}); vt = vis.get('visualType')
        if v.get('isHidden'): vh = True
        else: vh = False
        if vt == 'textbox' and v['position']['y'] < 70 and not vh:
            for para in vis.get('objects', {}).get('general', [{}])[0].get('properties', {}).get('paragraphs', []):
                for r in para.get('textRuns', []):
                    if isinstance(r.get('value'), str) and r['value'].strip(): header.append(r['value'].strip())
        if vt == 'cardVisual' and v['position']['y'] < 70 and not vh:   # page title card (refactoring step 50): label = title measure
            for lab in vis.get('objects', {}).get('label', []):
                e = lab.get('properties', {}).get('text', {}).get('expr', {})
                if 'Measure' in e:
                    he_t, en_t = measure_texts(e['Measure']['Property'])
                    header.append(he_t or '[%s]' % e['Measure']['Property']); header_en.append(en_t)
        refs = [pr.get('queryRef') for r in vis.get('query', {}).get('queryState', {}).values() for pr in r.get('projections', [])]
        if vt in ('slicer', 'advancedSlicerVisual', 'listSlicer') and refs and 'CT_BlankTable' not in refs[0]:
            flt = vis.get('objects', {}).get('general', [{}])[0].get('properties', {}).get('filter', {}).get('filter')
            default = cond_text(flt.get('Where')) if flt else '(All)'
            mode = vis.get('objects', {}).get('data', [{}])[0].get('properties', {}).get('mode', {}).get('expr', {}).get('Literal', {}).get('Value', '').strip("'")
            vf = filters_text(v.get('filterConfig', {}).get('filters', []), False)
            se = 'yes' if any('Show Existing' in t for t in vf) else ''
            fld = refs[0]; fen = FIELD_EN.get(fld, '')
            short = {'Calendar.Month Year Current': 'Month', 'סוגי מסמך.סוג מסמך': 'Document type', 'Salespersons.SalespersonName': 'Agent (document)'}.get(fld, fld)
            nvals = len(re.findall(r'"Value"', json.dumps(flt.get('Where', '')))) if flt else 0
            slicer_rows.append([grp, vis_index if not hidden else '', name, EN.get(name, ''), short, fld + (' (%s)' % fen if fen else ''),
                                mode or '', default, nvals if short == 'Agent (document)' and flt else '', se, '; '.join(t for t in vf if 'Show Existing' not in t), 'hidden' if vh else '', v['name']])
            if not vh:
                slicers.append('%s = %s' % (short, default if len(default) < 60 else default[:57] + '…'))
                key = {'Month': 'Month default', 'Document type': 'Doc type default', 'Agent (document)': 'Agent default'}.get(short)
                if key:
                    cons[name][key] = ('saved list (%d)' % nvals) if (short == 'Agent (document)' and flt) else default
                    if short == 'Agent (document)': cons[name]['Agent slicer show-existing'] = se or 'no'
        elif vt in DATA:
            shown, he, en, src = title_of(v)
            vf = filters_text(v.get('filterConfig', {}).get('filters', []), False)
            visual_rows.append([grp, vis_index if not hidden else '', name, EN.get(name, ''), vt, he if shown else '(title off) ' + he,
                                en if shown else ('(title off) ' + en if en else ''), src, ', '.join(r for r in refs if r)[:300],
                                '; '.join(vf), 'hidden' if vh else '', v['name']])
            if not vh: datav.append(vf)
    for t in pfl:
        k = t.split(':')[0]; cons[name]['Page filter ' + k] = t.split(': ', 1)[1]
    htxt = ' '.join(header)
    hen = ' '.join(header_en) or HEAD_EN.get(htxt.strip(), '')
    pages_rows.append([grp, vis_index if not hidden else '', name, EN.get(name, ''), ptype, 'hidden' if hidden else 'visible',
                       htxt, hen, '\n'.join(pfl) or '-', '\n'.join(slicers) or '-', len(datav), p])

# ---------- consistency: per group, value differing from the group majority ----------
cons_rows = []; flags = defaultdict(list)
by_group = defaultdict(list)
for r in pages_rows: by_group[r[0]].append(r[2])
for g, names in by_group.items():
    keys = sorted({k for n in names for k in cons[n]})
    for k in keys:
        vals = [cons[n].get(k, '—') for n in names]
        # page filters: values differ by design (Family / agent / manager per page) -> compare presence + hidden/locked only
        norm = (lambda v: '—' if v == '—' else 'set' + (' [' + v.split('[', 1)[1] if '[' in v else '')) if k.startswith('Page filter') else (lambda v: v)
        nv = [norm(v) for v in vals]
        common, cnt = Counter(nv).most_common(1)[0]
        for n, v, x in zip(names, vals, nv):
            diff = len(names) > 1 and x != common and cnt > 1
            shown_common = common if not k.startswith('Page filter') else ('filter present' + (' [' + common.split('[', 1)[1] if '[' in common else '') if common != '—' else 'no filter')
            cons_rows.append([g, n, EN.get(n, ''), k, v, shown_common if diff else '', 'DIFFERS' if diff else ''])
            if diff:   # plain sentence: what this page has vs what most pages of its group have
                if v == '—':
                    flags[n].append('%s: this page has none; most pages in the group: %s' % (k, shown_common))
                elif common == '—':
                    flags[n].append('%s: this page has %s; most pages in the group have none' % (k, v))
                else:
                    flags[n].append('%s: this page = %s; most pages in the group = %s' % (k, v, shown_common))
for r in pages_rows: r.insert(11, '\n'.join(flags.get(r[2], [])))
# reviewer comments: carried over from the existing output file by page id ("Comments" column; first run: text the reviewer
# typed into the flags column, i.e. a cell that is not a generated flag)
OLD_COMMENTS = {}
if os.path.exists(out):
    try:
        import shutil, tempfile, openpyxl as _ox
        tmp = os.path.join(tempfile.gettempdir(), 'reportmap_old.xlsx'); shutil.copyfile(out, tmp)   # the file may be open
        wso = _ox.load_workbook(tmp)['Pages']; hdr = [c.value for c in wso[1]]
        ip = hdr.index('Page id'); ic = hdr.index('Comments') if 'Comments' in hdr else None; ifl = hdr.index('Consistency flags')
        for row in wso.iter_rows(min_row=2, values_only=True):
            txt = row[ic] if ic is not None else None
            if ic is None and row[ifl] and not re.search(r'\(group: |most pages in the group', str(row[ifl])): txt = row[ifl]
            if txt: OLD_COMMENTS[row[ip]] = txt
    except (OSError, KeyError, ValueError) as e:
        print('old comments not read:', e)
for r in pages_rows: r.append(OLD_COMMENTS.get(r[12], ''))

# ---------- allocations: where each field is used (page filters, slicers, visual fields, visual filters) ----------
def field_usage():
    use = defaultdict(lambda: defaultdict(set))   # 'Table.Column' -> role -> {page names}
    def fkey(fld):
        n = field_name(fld); m = re.match(r'(.+?)\[(.+)\]$', n)
        return '%s.%s' % (m.group(1), m.group(2)) if m else n
    for p in order:
        pj = json.load(open(os.path.join(base, p, 'page.json'), encoding='utf-8')); name = pj['displayName']
        if pj.get('type') == 'Tooltip' or p.startswith('TT'): continue
        for x in pj.get('filterConfig', {}).get('filters', []):
            if x.get('filter'): use[fkey(x.get('field', {}))]['page filter'].add(name)
        for f in glob.glob(os.path.join(base, p, 'visuals', '*', 'visual.json')):
            v = json.load(open(f, encoding='utf-8')); vis = v.get('visual', {}); vt = vis.get('visualType')
            if v.get('isHidden'): continue
            refs = [pr.get('queryRef') for r in vis.get('query', {}).get('queryState', {}).values() for pr in r.get('projections', [])]
            role = 'slicer' if vt in ('slicer', 'advancedSlicerVisual', 'listSlicer') else 'visual field'
            for r in refs:
                if r: use[r][role].add(name)
            for x in v.get('filterConfig', {}).get('filters', []):
                if x.get('filter'): use[fkey(x.get('field', {}))]['visual filter'].add(name)
    return use
alloc_rows = []
if cfg.get('allocations'):
    U = field_usage()
    for a in cfg['allocations']:
        for fld in a.get('fields', []):
            u = U.get(fld, {})
            pages_any = sorted(set().union(*u.values())) if u else []
            alloc_rows.append([a.get('concept', ''), a.get('rule', ''), a.get('source', ''), fld,
                               '; '.join('%s: %d' % (k, len(v)) for k, v in sorted(u.items())) or 'not used in the report',
                               ', '.join('%s (%s)' % (n, EN.get(n, '')) if EN.get(n) else n for n in pages_any), a.get('notes', '')])

def read_datatable(tname):
    f = os.path.join(root, stem + '.SemanticModel', 'definition', 'tables', tname + '.tmdl')
    t = open(f, encoding='utf-8').read()
    body = t.split('DATATABLE', 1)[1]
    head, rows_txt = body.split('{', 1)
    cols = re.findall(r'"([^"]+)"\s*,\s*(?:STRING|INTEGER|DOUBLE|BOOLEAN|CURRENCY|DATETIME)', head)
    tok = re.compile(r'"((?:[^"]|"")*)"|BLANK\s*\(\s*\)|(-?\d+(?:\.\d+)?)')
    rows = []
    for line in rows_txt.splitlines():
        line = line.split('--')[0].strip()
        if not line.startswith('{'): continue
        vals = [(m.group(1).replace('""', '"') if m.group(1) is not None else (m.group(2) or '')) for m in tok.finditer(line)]
        if len(vals) == len(cols): rows.append(vals)
    return cols, rows

# ---------- workbook ----------
wb = Workbook()
HDR = Font(bold=True, color='FFFFFF'); FILL = PatternFill('solid', fgColor='134591'); RED = PatternFill('solid', fgColor='F8D7DA')
WRAP = Alignment(wrap_text=True, vertical='top')
def sheet(ws, title, header, rows, widths, flagcol=None, freeze='D2'):
    ws.title = title; ws.append(header)
    for c in ws[1]: c.font = HDR; c.fill = FILL; c.alignment = Alignment(wrap_text=True, vertical='center')
    for r in rows: ws.append(r)
    for row in ws.iter_rows(min_row=2):   # text like "= 6" must stay text, not become a (broken) formula
        for c in row:
            if c.data_type == 'f': c.value = str(c.value); c.data_type = 's'
    for i, w in enumerate(widths, 1): ws.column_dimensions[get_column_letter(i)].width = w
    for row in ws.iter_rows(min_row=2):
        for c in row: c.alignment = WRAP
        if flagcol is not None and row[flagcol].value:
            for c in row: c.fill = RED
    ws.freeze_panes = freeze; ws.auto_filter.ref = ws.dimensions   # set once: a second freeze leaves an invalid view (Excel repair)
ws = wb.active
PURPOSE.setdefault('? (not grouped)', 'pages missing from the config') if '? (not grouped)' in by_group else None
grp_rows = [[g, PURPOSE[g], ', '.join('%s (%s)' % (n, EN.get(n, '')) for n in by_group.get(g, []))] for g in PURPOSE]
sheet(ws, 'Groups', ['Group', 'Purpose', 'Pages'], grp_rows, [24, 60, 110], freeze='B2')
sheet(wb.create_sheet(), 'Pages', ['Group', 'Tab #', 'Page (tab name)', 'Page (En)', 'Type', 'Visibility', 'Header text',
      'Header text (En)', 'Page filters', 'Slicers = saved default', 'Visible data visuals', 'Consistency flags', 'Page id', 'Comments'],
      pages_rows, [20, 6, 22, 26, 13, 9, 34, 34, 45, 55, 9, 60, 26, 50], flagcol=11)
sheet(wb.create_sheet(), 'Slicers', ['Group', 'Tab #', 'Page', 'Page (En)', 'Slicer', 'Field', 'Mode', 'Saved default value',
      'Agents in saved list', 'Show-existing filter', 'Other visual filters', 'Hidden', 'Visual id'], slicer_rows,
      [20, 6, 22, 24, 16, 34, 10, 60, 10, 10, 30, 8, 22])
sheet(wb.create_sheet(), 'Visuals', ['Group', 'Tab #', 'Page', 'Page (En)', 'Visual type', 'Title (He)', 'Title (En)', 'Title source',
      'Fields', 'Visual filters', 'Hidden', 'Visual id'], visual_rows, [20, 6, 20, 22, 14, 30, 30, 26, 60, 50, 8, 22])
sheet(wb.create_sheet(), 'Consistency', ['Group', 'Page', 'Page (En)', 'Setting', 'Value', 'Most common in group', 'Flag'], cons_rows,
      [20, 22, 24, 30, 60, 40, 9], flagcol=6)
if alloc_rows:
    sheet(wb.create_sheet(), 'Allocation', ['Concept', 'Rule (how a sale / customer / item is assigned)', 'Source', 'Model field',
          'Used as (pages)', 'Pages', 'Notes'], alloc_rows, [22, 55, 34, 32, 34, 70, 45], freeze='B2')
import openpyxl
YELLOW = PatternFill('solid', fgColor='FFF2CC')
for spec in cfg.get('model_tables', []):
    spec = {'table': spec} if isinstance(spec, str) else spec
    tname = spec['table']
    try:
        cols, rows = read_datatable(tname)
    except (OSError, IndexError):
        print('model table not readable as DATATABLE:', tname); continue
    lk = spec.get('lookup')   # extra columns from an xlsx, matched on a key column
    if lk:
        try:
            wsx = openpyxl.load_workbook(lk['file'], data_only=True)[lk['sheet']]
            hdr = [str(c.value).strip() if c.value is not None else '' for c in wsx[1]]
            ki = hdr.index(lk['key']); ci = [hdr.index(c) for c in lk['columns']]
            look = {str(r[ki]).strip(): [r[i] for i in ci] for r in wsx.iter_rows(min_row=2, values_only=True) if r[ki] is not None}
            mi = cols.index(lk.get('model_key', lk['key']))
            cols = cols + [lk.get('label', {}).get(c, c) for c in lk['columns']]
            rows = [r + look.get(str(r[mi]).strip(), [None] * len(ci)) for r in rows]
        except (OSError, KeyError, ValueError) as e:
            print('lookup skipped for', tname, e)
    ws2 = wb.create_sheet()
    sheet(ws2, ('Data ' + tname)[:31], cols, rows, [max(10, min(36, max([len(str(c))] + [len(str(r[i] or '')) for r in rows]) + 2)) for i, c in enumerate(cols)], freeze='B2')
    hb = [cols.index(c) for c in spec.get('highlight_blank', []) if c in cols]   # rows with a blank key column -> yellow
    nhb = 0
    for row in ws2.iter_rows(min_row=2):
        if any(row[i].value in (None, '') for i in hb):
            nhb += 1
            for c in row: c.fill = YELLOW
    if hb: print('Data %s: %d rows highlighted (blank %s)' % (tname, nhb, ', '.join(spec['highlight_blank'])))
if cfg.get('notes'):
    ws3 = wb.create_sheet()
    sheet(ws3, 'Notes', ['Note'], [[n] for n in cfg['notes']], [140], freeze=None)
wb.save(out)
print('pages', len(pages_rows), '| slicers', len(slicer_rows), '| visuals', len(visual_rows), '| consistency rows', len(cons_rows),
      '| flagged', sum(1 for r in cons_rows if r[6]), '| not grouped:', [r[2] for r in pages_rows if r[0].startswith('?')])

