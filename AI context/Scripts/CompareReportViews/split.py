# Assign traced visual queries (QueryEnd / DAXQuery) to pages by the screenshot time windows -> queries.json
import csv, json, os
from datetime import datetime, timezone

here = os.path.dirname(os.path.abspath(__file__))
PORT = {'cur': 53266, 'pdf': 51252}
log = list(csv.DictReader(open(os.path.join(here, 'pages_log.csv'), encoding='utf-8-sig')))
win = {}
for r in log:
    win.setdefault(r['Report'], []).append((datetime.fromisoformat(r['Start'][:26] + '+00:00'), datetime.fromisoformat(r['End'][:26] + '+00:00'), r['Page']))
out = []
for rep in ('cur', 'pdf'):
    ev = json.load(open(os.path.join(here, f'trace_{rep}.json'), encoding='utf-8'))['events']
    counts = {}
    for i, e in enumerate(ev):
        if e.get('eventSubclassName') != 'DAXQuery' or not e['applicationName'].startswith('Power BI Desktop'):
            continue
        t = datetime.fromisoformat(e['startTime']).astimezone(timezone.utc)
        page = next((p for s, en, p in win[rep] if s <= t <= en), None)
        counts[page] = counts.get(page, 0) + 1
        out.append({'id': f'{rep}_{i}', 'rep': rep, 'port': PORT[rep], 'page': page, 'query': e['textData']})
    print(rep, {k: v for k, v in sorted(counts.items(), key=lambda x: str(x[0]))})
json.dump(out, open(os.path.join(here, 'queries.json'), 'w', encoding='utf-8'), ensure_ascii=False)
