# Compare two PBIP semantic models (TMDL) object by object and carry changes from a source model
# (e.g. a dev copy) into a target model; rename measures in a report after a measure rename.
#
# Usage:
#   python -I -X utf8 MergeSemanticModel.py compare <src.SemanticModel> <dst.SemanticModel> [--report <dst.Report>]
#   python -I -X utf8 MergeSemanticModel.py merge   <src.SemanticModel> <dst.SemanticModel>
#          [--exclude "Measure/Measure 2"] [--keep "Measure/DDC #"] [--skip-table T] [--apply]
#   python -I -X utf8 MergeSemanticModel.py rename-measures <X.Report> --map "Old=New" [--map ...] [--apply]
#
# compare - tables only in one model; per table: added / removed / changed measures, columns,
#   partitions, calculation items (lineageTag and line endings ignored); relationships; with --report:
#   target-report visuals that use measures the source lacks (they break after a merge) + rename
#   candidates (removed measure whose DAX matches an added one).
# merge - every table that is new or differs in the source is copied over the target's file, then:
#   --exclude Table/Object drops an object from the copied file (junk in the source),
#   --keep Table/Object re-inserts a target object the source no longer has (still used by visuals).
#   New tables get "ref table" in model.tmdl; source relationships missing in the target (by id) whose
#   tables both exist are appended. Target-only tables / relationships are listed, never removed.
#   Cultures (linguistic metadata), diagramLayout.json, model annotations are not touched.
# rename-measures - replaces quoted tokens (?<=[".])Old(?=") in every report JSON (Property, queryRef,
#   nativeQueryRef, filters, bookmarks); text-only, so CRLF / BOM stay.
# Dry run by default; --apply writes after a backup to the nearest "BackUp" folder above the target
# (MergeSemanticModel_<timestamp>). Desktop open on the target: check `powerbi-desktop status`
# (no unsaved changes) before --apply, then `powerbi-desktop reload`.
#
# SCRIPT_VERSION: 2026-10-20.1
import argparse, difflib, re, shutil, sys
from datetime import datetime
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')
OBJ = re.compile(r"^\t(measure|column|partition|hierarchy|calculationGroup|annotation|changedProperty)\s+('[^']*'|[^\s=]+)")
CITEM = re.compile(r"^\t\tcalculationItem\s+('[^']*'|[^\s=]+)")


def read(p): return p.read_bytes().decode('utf-8')
def write(p, s): p.write_bytes(s.encode('utf-8'))
def nl_of(s): return '\r\n' if '\r\n' in s else '\n'
def unq(n): return n[1:-1].replace("''", "'") if n.startswith("'") else n


def split_blocks(text):
    """(header, [(kind, name, text)]) split on one-tab objects; '\t///' doc comments go with the next object."""
    head, blocks, cur, pending = [], [], None, []
    for ln in text.splitlines(keepends=True):
        if ln.startswith('\t///'):
            pending.append(ln); continue
        m = OBJ.match(ln)
        if m:
            cur = [m.group(1), unq(m.group(2)), pending + [ln]]; pending = []
            blocks.append(cur); continue
        if pending:
            (cur[2] if cur else head).extend(pending); pending = []
        (cur[2] if cur else head).append(ln)
    return ''.join(head), [(k, n, ''.join(b)) for k, n, b in blocks]


def objects(text):
    """{(kind, name): text} incl. calculation items (nested in a calculationGroup block)."""
    out = {}
    for k, n, b in split_blocks(text)[1]:
        if k in ('annotation', 'changedProperty'): continue
        out[(k, n)] = b
        if k == 'calculationGroup':
            cur = None
            for ln in b.splitlines(keepends=True):
                m = CITEM.match(ln)
                if m: cur = ('calculationItem', unq(m.group(1))); out[cur] = ''
                elif cur and not re.match(r'^\t\t\S', ln): out[cur] += ln
                else: cur = None
    return out


def norm(t): return '\n'.join(l.rstrip() for l in t.splitlines() if l.strip() and 'lineageTag:' not in l)
def dax(t):
    """Measure DAX only: no name, comments, fences or property lines."""
    body = t.split('=', 1)[1] if '=' in t.splitlines()[0] else ''
    body = '\n'.join(l for l in body.splitlines() if not re.match(r'\s*(lineageTag|formatString|displayFolder|annotation|changedProperty|isHidden)\b', l))
    return re.sub(r'\s+', ' ', re.sub(r'//[^\n]*|--[^\n]*|```', '', body)).strip()


def tables(sm): return {p.stem: p for p in sorted((sm / 'definition/tables').glob('*.tmdl'))}


def relationships(sm):
    p = sm / 'definition/relationships.tmdl'
    t = read(p) if p.exists() else ''
    return {m.group(1): m.group(0) for m in re.finditer(r'^relationship ([^\r\n]+)\r?\n(?:\t[^\r\n]*\r?\n?)+', t, re.M)}


def rel_tables(r): return {unq(m.group(1)) for m in re.finditer(r"(?:from|to)Column:\s*('[^']*'|[^.\s]+)\.", r)}


def backup(dst):
    base = next((p / 'BackUp' for p in dst.resolve().parents if (p / 'BackUp').is_dir()), dst.parent / 'BackUp')
    b = base / f"MergeSemanticModel_{datetime.now():%Y%m%d_%H%M%S}" / dst.name
    shutil.copytree(dst, b); print('backup:', b)


def compare(a):
    src, dst = Path(a.src), Path(a.dst)
    ts, td = tables(src), tables(dst)
    print('Tables only in source:', sorted(set(ts) - set(td)) or '-')
    print('Tables only in target:', sorted(set(td) - set(ts)) or '-')
    src_m, removed_m = {}, {}
    def props(t): return norm(''.join(b for k, _, b in split_blocks(t)[1] if k in ('annotation', 'changedProperty')) + split_blocks(t)[0])
    for t in sorted(set(ts) & set(td)):
        os_, od = objects(read(ts[t])), objects(read(td[t]))
        src_m.update({k[1]: v for k, v in os_.items() if k[0] == 'measure'})
        add = [k for k in os_ if k not in od]; rem = [k for k in od if k not in os_]
        chg = [k for k in os_ if k in od and norm(os_[k]) != norm(od[k])]
        tprop = props(read(ts[t])) != props(read(td[t]))
        if not (add or rem or chg or tprop): continue
        print(f'== {t}: +{len(add)} -{len(rem)} ~{len(chg)}')
        for tag, ks in (('+', add), ('-', rem), ('~', chg)):
            for k in ks: print(f'   {tag} {k[0]} {k[1]}')
        if tprop: print('   ~ table header / annotations')
        removed_m.update({k[1]: od[k] for k in rem if k[0] == 'measure'})
    rs, rd = relationships(src), relationships(dst)
    for tag, ks, r in (('+', set(rs) - set(rd), rs), ('-', set(rd) - set(rs), rd)):
        for k in sorted(ks): print(f'rel {tag} {k}: {" -> ".join(re.findall(r"(?:from|to)Column:\s*(.+)", r[k]))}')
    for k in sorted(set(rs) & set(rd)):
        if norm(rs[k]) != norm(rd[k]): print(f'rel ~ {k}')
    if removed_m:
        print('\nRemoved measures -> closest source measure by DAX (>= 0.85 = rename / merge candidate):')
        for r, body in removed_m.items():
            sim = {x: difflib.SequenceMatcher(None, dax(body), dax(v)).ratio() for x, v in src_m.items()}
            best = max(sim, key=sim.get, default=None)
            same = best and dax(body) == dax(src_m[best])
            print(f'   {r}  ~>  {best if best and sim[best] >= 0.85 else "(none)"}  ({"identical" if same else f"{sim.get(best, 0):.3f}"})')
    if a.report and removed_m:
        rep = Path(a.report); pages = {}
        for pj in rep.glob('definition/pages/*/page.json'):
            m = re.search(r'"displayName":\s*"([^"]*)"', read(pj)); pages[pj.parent.name] = m.group(1) if m else pj.parent.name
        print('\nTarget report visuals using measures the source lacks:')
        for r in removed_m:
            hits = sorted({pages.get(f.relative_to(rep / 'definition/pages').parts[0], f.name) if 'pages' in f.parts else f.name
                           for f in rep.rglob('*.json') if re.search(r'"Property":\s*"' + re.escape(r) + '"', read(f))})
            print(f'   {r}: {hits or "-"}')


def merge(a):
    src, dst = Path(a.src), Path(a.dst)
    ts, td = tables(src), tables(dst)
    excl = {tuple(x.split('/', 1)) for x in a.exclude}; keep = {tuple(x.split('/', 1)) for x in a.keep}
    plan = {}
    for t, p in ts.items():
        if t in a.skip_table: continue
        new = t not in td
        if not new and read(p).replace('\r\n', '\n') == read(td[t]).replace('\r\n', '\n') \
                and not any(x[0] == t for x in excl | keep): continue
        head, blocks = split_blocks(read(p))
        drop = [b for b in blocks if (t, b[1]) in excl]
        blocks = [b for b in blocks if (t, b[1]) not in excl]
        kept = []
        if not new:
            names = {b[1] for b in blocks}
            kept = [b for b in split_blocks(read(td[t]))[1] if (t, b[1]) in keep and b[1] not in names]
            i = next((i for i, b in enumerate(blocks) if b[0] not in ('measure', 'column')), len(blocks))
            nl = nl_of(read(p))
            blocks[i:i] = [(k, n, b if b.endswith(nl * 2) else b.rstrip('\r\n') + nl * 2) for k, n, b in kept]
        plan[t] = (new, head + ''.join(b[2] for b in blocks), [b[1] for b in drop], [b[1] for b in kept])
    for x in excl | keep:
        if x[0] not in plan: print(f'WARN {x[0]}/{x[1]}: table not merged')
    final = set(td) | set(plan)
    rs, rd = relationships(src), relationships(dst)
    rel_add = [k for k in rs if k not in rd and rel_tables(rs[k]) <= final]
    for t, (new, _, drop, kept) in sorted(plan.items()):
        print(f"{'NEW ' if new else 'UPD '} {t}" + (f'  excluded={drop}' if drop else '') + (f'  kept={kept}' if kept else ''))
    for k in rel_add: print('REL+', k, ' -> '.join(re.findall(r'(?:from|to)Column:\s*(.+)', rs[k])))
    for k in sorted(set(rd) - set(rs)): print('REL target-only (kept):', k)
    print('Target-only tables (kept):', sorted(set(td) - set(ts)) or '-')
    if not a.apply: print('\nDry run - add --apply to write.'); return
    backup(dst)
    for t, (new, text, _, _) in plan.items(): write(dst / f'definition/tables/{t}.tmdl', text)
    mp = dst / 'definition/model.tmdl'; mt = read(mp); nl = nl_of(mt)
    refs = [f"ref table {n if re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', n) else chr(39) + n.replace(chr(39), chr(39) * 2) + chr(39)}"
            for n, (new, *_) in plan.items() if new]
    refs = [r for r in refs if not re.search('^' + re.escape(r) + r'\r?$', mt, re.M)]
    if refs:
        last = list(re.finditer(r'^ref table [^\r\n]*', mt, re.M))[-1]
        mt = mt[:last.end()] + ''.join(nl + r for r in refs) + mt[last.end():]
        write(mp, mt)
    if rel_add:
        rp = dst / 'definition/relationships.tmdl'; rt = read(rp) if rp.exists() else ''; nl = nl_of(rt or mt)
        rt = rt.rstrip('\r\n') + nl * 2 if rt else ''
        rt += (nl * 2).join(rs[k].replace('\r\n', '\n').rstrip('\n').replace('\n', nl) for k in rel_add) + nl * 2
        write(rp, rt)
    print('written.')


def rename_measures(a):
    rep = Path(a.report); pairs = [m.split('=', 1) for m in a.map]
    hits = {}
    for f in rep.rglob('*.json'):
        t = read(f); n = t
        for old, new in pairs: n = re.sub(r'(?<=[".])' + re.escape(old) + r'(?=")', new.replace('\\', r'\\'), n)
        if n != t: hits[f] = n
    for f in hits: print('  ', f.relative_to(rep))
    print(f'{len(hits)} files')
    if not a.apply: print('Dry run - add --apply to write.'); return
    if hits: backup(rep)
    for f, n in hits.items(): write(f, n)
    print('written.')


ap = argparse.ArgumentParser(); sp = ap.add_subparsers(dest='cmd', required=True)
c = sp.add_parser('compare'); c.add_argument('src'); c.add_argument('dst'); c.add_argument('--report')
m = sp.add_parser('merge'); m.add_argument('src'); m.add_argument('dst')
m.add_argument('--exclude', action='append', default=[]); m.add_argument('--keep', action='append', default=[])
m.add_argument('--skip-table', action='append', default=[]); m.add_argument('--apply', action='store_true')
r = sp.add_parser('rename-measures'); r.add_argument('report'); r.add_argument('--map', action='append', required=True)
r.add_argument('--apply', action='store_true')
a = ap.parse_args()
{'compare': compare, 'merge': merge, 'rename-measures': rename_measures}[a.cmd](a)
