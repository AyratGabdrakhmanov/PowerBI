# Static check of PBIR bookmarks and bookmark buttons - no Desktop, no clicking.
#
# Usage:
#   python CheckBookmarks.py "<...>.Report\definition" [--ref "<known-good ...>.Report\definition"]
#
# Checks
#   A  structure   - activeSection / section pages, visualContainers, groups, targetVisualNames exist
#   B  buttons     - every Bookmark-action button points to an existing bookmark on ITS OWN page
#   C  slicers     - every slicer state in a bookmark matches the field of the slicer with that name
#   D  vs --ref    - per bookmark, per visual: shown/hidden now vs the reference report (pages matched by
#                    displayName, visuals by type + position); visuals missing on either side are listed
#   E  dead items  - bookmarks no button/navigator calls; visuals hidden by default that no bookmark shows
import json, glob, os, re, sys

args = [a for a in sys.argv[1:]]
D = args[0]
REF = args[args.index('--ref') + 1] if '--ref' in args else None

def load(d):
    pages = {}
    for p in glob.glob(f'{d}/pages/*/page.json'):
        pg = os.path.basename(os.path.dirname(p))
        vis = {}
        for f in glob.glob(f'{d}/pages/{pg}/visuals/*/visual.json'):
            j = json.load(open(f, encoding='utf-8'))
            vis[j['name']] = j
        pages[pg] = {'name': json.load(open(p, encoding='utf-8'))['displayName'].strip(), 'vis': vis}
    bms = {}
    for f in glob.glob(f'{d}/bookmarks/*.bookmark.json'):
        j = json.load(open(f, encoding='utf-8')); bms[j['name']] = j
    return pages, bms

def vtype(j): return (j.get('visual') or {}).get('visualType') or ('group' if 'visualGroup' in j else '?')
def fields(o): return set(x.lower() for x in re.findall(r'"(?:Property|Hierarchy|Level)": "([^"]+)"', json.dumps(o, ensure_ascii=False)))
def pos(j):
    p = j.get('position', {}); return tuple(round(float(p.get(k, 0))) for k in ('x', 'y', 'width', 'height'))
def mode(e):
    if e is None: return None
    if 'singleVisualGroup' in e: return 'hidden' if e['singleVisualGroup'].get('isHidden') else 'shown'
    return ((e.get('singleVisual') or {}).get('display') or {}).get('mode', 'shown')
def title(j):
    t = re.findall(r'"text"[^}]*?"Value": "\'([^\']{1,40})\'"', json.dumps(j.get('visual', {}), ensure_ascii=False))
    return t[0] if t else ''

pages, bms = load(D)
issues = {k: [] for k in 'ABCDE'}

# A - structure
for b in bms.values():
    es = b['explorationState']; act = es.get('activeSection')
    if act not in pages: issues['A'].append(f"{b['displayName']}: activeSection '{act}' does not exist"); continue
    for pg, sec in es.get('sections', {}).items():
        if pg not in pages: issues['A'].append(f"{b['displayName']}: section for missing page '{pg}'"); continue
        for key in ('visualContainers', 'visualContainerGroups'):
            for n in (sec.get(key) or {}):
                if n not in pages[pg]['vis']: issues['A'].append(f"{b['displayName']} [{pg}]: {key} '{n}' does not exist")
    for n in b.get('options', {}).get('targetVisualNames', []) or []:
        if n not in pages[act]['vis']: issues['A'].append(f"{b['displayName']} [{act}]: target '{n}' does not exist")

# B - buttons
called = set()
for pg, P in pages.items():
    for n, j in P['vis'].items():
        t = json.dumps(j, ensure_ascii=False)
        for bm in re.findall(r"'(Bookmark[0-9a-f]{20}|[0-9a-f]{20})'", t):
            if bm in bms:
                called.add(bm)
                tgt = bms[bm]['explorationState'].get('activeSection')
                if tgt != pg:
                    issues['B'].append(f"[{pg} {P['name']}] {n} '{title(j)}' -> '{bms[bm]['displayName']}' opens ANOTHER page {tgt}")
            elif bm.startswith('Bookmark'):
                issues['B'].append(f"[{pg} {P['name']}] {n} '{title(j)}' -> missing bookmark {bm}")
        if vtype(j) == 'bookmarkNavigator':
            called.update(bms)                          # navigator shows bookmark groups - treat all as reachable

# C - slicer states
for b in bms.values():
    es = b['explorationState']; act = es.get('activeSection')
    if act not in pages: continue
    for n, e in (es.get('sections', {}).get(act, {}).get('visualContainers') or {}).items():
        j = pages[act]['vis'].get(n)
        if not j or vtype(j) != 'slicer': continue
        ef = fields((e.get('singleVisual') or {}).get('activeProjections', {})) or fields(e.get('filters', {}))
        if ef and not (ef & fields(j['visual'].get('query', {}))):
            issues['C'].append(f"{b['displayName']} [{act}] {n}: state for {sorted(ef)}, slicer has {sorted(fields(j['visual'].get('query', {})))}")

# D - shown/hidden vs reference
if REF:
    rpages, rbms = load(REF)
    by_name = {P['name']: pg for pg, P in pages.items()}
    for rb_name, rb in rbms.items():
        if rb_name not in bms: continue
        b = bms[rb_name]
        ract = rb['explorationState'].get('activeSection'); act = b['explorationState'].get('activeSection')
        if ract not in rpages or by_name.get(rpages[ract]['name']) != act: continue
        rv, cv = rpages[ract]['vis'], pages[act]['vis']
        # visual map ref -> current by type + position (+ fields)
        m, used = {}, set()
        for n, j in rv.items():
            cand = [c for c in cv if c not in used and vtype(cv[c]) == vtype(j)]
            if not cand: continue
            best = min(cand, key=lambda c: sum(abs(a - b_) for a, b_ in zip(pos(cv[c]), pos(j))) + (0 if fields(cv[c].get('visual', {}).get('query', {})) == fields(j.get('visual', {}).get('query', {})) else 50))
            if sum(abs(a - b_) for a, b_ in zip(pos(cv[best]), pos(j))) <= 60: m[n] = best; used.add(best)
        rsec = rb['explorationState']['sections'].get(ract, {}); csec = b['explorationState']['sections'].get(act, {})
        rvc = {**(rsec.get('visualContainers') or {}), **(rsec.get('visualContainerGroups') or {})}
        cvc = {**(csec.get('visualContainers') or {}), **(csec.get('visualContainerGroups') or {})}
        for rn, cn in m.items():
            a, c = mode(rvc.get(rn)), mode(cvc.get(cn))
            if a != c:
                issues['D'].append(f"{b['displayName']} [{act}] {cn} ({vtype(cv[cn])} '{title(cv[cn])}'): ref {a or 'no state'} -> now {c or 'no state'}")

# E - dead items
for bm, b in bms.items():
    if bm not in called:
        issues['E'].append(f"bookmark '{b['displayName']}' [{b['explorationState'].get('activeSection')}] - no button/navigator calls it")
for pg, P in pages.items():
    shown = set()
    for b in bms.values():
        if b['explorationState'].get('activeSection') != pg: continue
        for n, e in (b['explorationState']['sections'].get(pg, {}).get('visualContainers') or {}).items():
            if mode(e) not in (None, 'hidden'): shown.add(n)
        for n, e in (b['explorationState']['sections'].get(pg, {}).get('visualContainerGroups') or {}).items():
            if mode(e) not in (None, 'hidden'): shown.add(n)
    for n, j in P['vis'].items():
        if j.get('isHidden') and n not in shown and not j.get('parentGroupName'):
            issues['E'].append(f"[{pg} {P['name']}] {n} ({vtype(j)} '{title(j)}') hidden by default, no bookmark shows it")

names = {'A': 'structure', 'B': 'buttons', 'C': 'slicer states', 'D': 'shown/hidden vs reference', 'E': 'dead items'}
for k in 'ABCDE':
    if k == 'D' and not REF: continue
    print(f'== {k} {names[k]}: {len(issues[k])}')
    for line in issues[k]: print('   ' + line)
