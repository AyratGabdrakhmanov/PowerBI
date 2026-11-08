"""PBIR visual.json helpers - edit a block or exact text without reformatting the rest of the file (position digits, CRLF).
   from PbirEdit import load, save_visual_keys, replace_text, col, lvl   (add the Scripts folder to PYTHONPATH)
   SCRIPT_VERSION: 2026-10-23.1"""
import json, pathlib


def col(t, c):
    return {'Column': {'Expression': {'SourceRef': {'Entity': t}}, 'Property': c}}


def lvl(h, l, entity='ChartOfAccounts'):
    return {'HierarchyLevel': {'Expression': {'Hierarchy': {'Expression': {'SourceRef': {'Entity': entity}}, 'Hierarchy': h}}, 'Level': l}}


def load(path):
    return json.loads(pathlib.Path(path).read_text(encoding='utf-8'))


def _block_end(t, i):
    depth, in_str, esc = 0, False, False
    while True:
        ch = t[i]
        if in_str:
            if esc:
                esc = False
            elif ch == chr(92):
                esc = True
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch in '{[':
            depth += 1
        elif ch in '}]':
            depth -= 1
            if depth == 0:
                return i
        i += 1


def save_visual_keys(path, j, keys, indent='    '):
    """Rewrite only the text of visual.<key> blocks; position digits etc. stay as Desktop wrote them."""
    p = pathlib.Path(path)
    t = p.read_bytes().decode('utf-8')
    nl = '\r\n' if '\r\n' in t else '\n'
    for k in keys:
        start = t.index(f'{nl}{indent}"{k}": ') + len(nl)
        i = t.index('{' if isinstance(j['visual'][k], dict) else '[', start)
        end = _block_end(t, i)
        block = f'{indent}"{k}": ' + json.dumps(j['visual'][k], ensure_ascii=False, indent=2).replace('\n', nl + indent)
        t = t[:start] + block + t[end + 1:]
    if json.loads(t) != j:
        raise SystemExit(f'{path}: rebuilt file differs from the intended JSON')
    p.write_bytes(t.encode('utf-8'))


def replace_text(path, reps):
    """Exact text replacements with expected counts; newline-aware ("\n" in new -> file newline)."""
    p = pathlib.Path(path)
    t = p.read_bytes().decode('utf-8')
    nl = '\r\n' if '\r\n' in t else '\n'
    for old, new, n in reps:
        c = t.count(old)
        if c != n:
            raise SystemExit(f'{path}: "{old}" found {c}x, expected {n}')
        t = t.replace(old, new.replace('\n', nl))
    json.loads(t)
    p.write_bytes(t.encode('utf-8'))
