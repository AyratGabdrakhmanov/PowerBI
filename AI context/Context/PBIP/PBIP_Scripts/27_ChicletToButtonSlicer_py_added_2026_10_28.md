Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `ChicletToButtonSlicer.py` (added 2026-10-28)

`python -I -X utf8 ClientA\_Documentation\Scripts\ChicletToButtonSlicer.py <X.Report> <fox|literal> [--dry]` — refactoring
step 3b: every `ChicletSlicer…` visual → native Button slicer (`advancedSlicerVisual`), same visual name, position,
z / tabOrder, parent group, field, saved selection, interactions, sync group, title, border. `fox` = colours bound to
the `_Measures` Color measures (Teal selected / Light / Blue Dark hover, ClientB `Page13`); `literal` = the chiclet's own
colours (model without Color measures — step 17 rebinds them later). Learned on 9 chiclets:
- Button tiles fill the visual (the chiclet's fixed tile width / height and padding are gone) — tiles look a bit bigger.
- Font: the chiclet draws text smaller at the same number — use ~0.8 × the chiclet size.
- Order: when the chiclet showed the items reversed, set the slicer sort to Descending.
- All converted slicers force one selected value; a chiclet with `forcedSelection = false` (clear = show all fields of a
  field parameter) loses that option.
- Dropped: `images`, `disabledColor`, `showDisabled`. The Chiclet custom visual stays in `report.json` until step 4
  (`CleanUnused.ps1` step 11) removes it as unused.
Check: screenshots of every page before / after (Fit to page), `pbir validate`, `CheckReportRefs.py`, bookmarks.
