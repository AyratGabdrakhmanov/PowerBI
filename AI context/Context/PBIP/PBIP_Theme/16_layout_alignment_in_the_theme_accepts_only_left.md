Part of [PBIP_Theme.md](../PBIP_Theme.md) (split 2026-11-06).

## ⚠️ `layout.alignment` in the theme accepts only `left`/`center`/`right` (not `middle`)

The schema (`#/definitions/alignment`) validates `layout.alignment` with a strict enum
`"left" | "center" | "right"`. The value `"middle"` (which can be copied out of habit
from `visualContainerObjects`/other contexts where "middle"
is appropriate, e.g. `verticalAlignment`) **fails validation**:
```
Validation error at /visualStyles/cardVisual/*/layout/0/alignment:
Must match one of the following enum values: "left", "center", "right"
```
Fix — replace it with `"center"` (horizontal centering).
