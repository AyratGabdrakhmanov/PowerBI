Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## ⚠️ Visuals can reference each other by folder ID

`page.json` contains `visualInteractions` — rules for how visuals interact
with each other (cross-filtering), which reference visuals **by their
folder name** (i.e. by the `name` value from `visual.json`):

```json
"visualInteractions": [
  {
    "source": "d9317c05b2ec2be69f80",
    "target": "b570c00a99d2fc499a53",
    "type": "DataFilter"
  }
]
```

**If you rename a visual's folder without updating these references, cross-filtering
between visuals will silently break** (the counterpart of a page silently disappearing when
names get out of sync). No other places referencing visuals by ID in the PBIP project
were found at the time of checking (no `bookmarks/`, no nested `visualGroup`
with child visuals in this project) — but if bookmarks
or visual grouping appear, it is worth re-checking.
