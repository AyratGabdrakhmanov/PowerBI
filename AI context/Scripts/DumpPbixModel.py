"""Dump the semantic-model metadata of a .pbix to JSON (offline, Desktop not needed).

Usage:  python -I -X utf8 DumpPbixModel.py <file.pbix> <out.json>
Needs pbixray installed in %LOCALAPPDATA%\\pbixray (see AI_Tools_MCP_CLI.md, section pbixray).
Prints only the object counts; read details from the JSON.
"""
import json, os, sys

sys.path.insert(0, os.path.join(os.environ['LOCALAPPDATA'], 'pbixray'))
from pbixray import PBIXRay

m = PBIXRay(sys.argv[1])
out = {}
for name in ('tables', 'schema', 'power_query', 'dax_measures', 'dax_columns', 'dax_tables', 'relationships', 'rls', 'statistics'):
    try:
        v = getattr(m, name)
        out[name] = v.to_dict(orient='records') if hasattr(v, 'to_dict') else list(v)
    except Exception as e:
        out[name] = f'ERROR {e}'
json.dump(out, open(sys.argv[2], 'w', encoding='utf-8'), ensure_ascii=False, indent=1, default=str)
for k, v in out.items():
    print(k, len(v) if isinstance(v, list) else v)
