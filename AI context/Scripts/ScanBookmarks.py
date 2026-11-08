"""Scan PBIR bookmarks: which visuals each bookmark shows / hides, grouped per page, plus field lists of toggled visuals."""
import json, sys, re
from pathlib import Path
from collections import defaultdict

rep = Path(sys.argv[1])
defn = rep / "definition"
pages = {}
visuals = {}  # (page, visual) -> info
for pj in (defn / "pages").glob("*/page.json"):
    p = json.loads(pj.read_text(encoding="utf-8"))
    pages[pj.parent.name] = p.get("displayName", pj.parent.name)
    for vj in (pj.parent / "visuals").glob("*/visual.json"):
        v = json.loads(vj.read_text(encoding="utf-8"))
        vis = v.get("visual", {})
        fields = sorted(set(re.findall(r'"queryRef":\s*"([^"]+)"', json.dumps(vis.get("query", {}), ensure_ascii=False))))
        visuals[(pj.parent.name, v["name"])] = dict(
            type=vis.get("visualType", "group" if "visualGroup" in v else "?"),
            parent=v.get("parentGroupName"),
            hidden=v.get("isHidden", False),
            fields=fields,
            title=v.get("visualGroup", {}).get("displayName", ""),
        )

bms = []
bdir = defn / "bookmarks"
meta = json.loads((bdir / "bookmarks.json").read_text(encoding="utf-8")) if (bdir / "bookmarks.json").exists() else {}
for bj in bdir.glob("*.bookmark.json"):
    b = json.loads(bj.read_text(encoding="utf-8"))
    st = b.get("explorationState", {})
    sec = st.get("activeSection")
    vc = st.get("sections", {}).get(sec, {}).get("visualContainers", {})
    hidden = sorted(k for k, x in vc.items() if x.get("singleVisual", {}).get("display", {}).get("mode") == "hidden")
    opts = b.get("options", {})
    targets = opts.get("targetVisualNames")
    bms.append(dict(name=b.get("displayName"), id=b["name"], page=sec, hidden=hidden, targets=targets,
                    data=not opts.get("suppressData", False), display=not opts.get("suppressDisplay", False)))

# buttons that trigger bookmarks
trig = defaultdict(list)
for (pg, vn), _ in visuals.items():
    vj = defn / "pages" / pg / "visuals" / vn / "visual.json"
    t = vj.read_text(encoding="utf-8")
    for bid in re.findall(r"'(Bookmark[0-9a-f]+)'", t):
        trig[bid].append(vn)

by_page = defaultdict(list)
for b in bms:
    by_page[b["page"]].append(b)

print(f"pages {len(pages)}, visuals {len(visuals)}, bookmarks {len(bms)}")
for pg, lst in sorted(by_page.items(), key=lambda x: pages.get(x[0], "")):
    # visuals whose visibility differs between bookmarks on this page = switched visuals
    allv = set().union(*[set(b["hidden"]) for b in lst]) if lst else set()
    switched = [v for v in allv if not all(v in b["hidden"] for b in lst)]
    print(f"\n== {pages.get(pg, pg)} [{pg}] bookmarks={len(lst)} switched visuals={len(switched)}")
    for b in sorted(lst, key=lambda x: x["name"] or ""):
        shown = [v for v in switched if v not in b["hidden"]]
        print(f"  BM '{b['name']}' data={b['data']} display={b['display']} targets={len(b['targets']) if b['targets'] else 'all'} "
              f"buttons={len(trig.get(b['id'], []))} shows={len(shown)}")
    for v in sorted(switched):
        i = visuals.get((pg, v))
        if i:
            print(f"    V {v[:20]} {i['type']} parent={(i['parent'] or '')[:20]} fields={i['fields']}")
        else:
            print(f"    V {v[:20]} (missing)")
orphan = [b["name"] for b in bms if not trig.get(b["id"])]
print(f"\nbookmarks with no button: {len(orphan)}")
