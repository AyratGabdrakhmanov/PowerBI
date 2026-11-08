Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 29. Bookmark switching → field parameters (all projects, user 2026-10-30)

Bookmarks that only switch between copies of one visual (same measures, another row / axis field: By Agent / Customer /
Item …) → **one** visual on a field parameter `FP_<Subject>` (He / En labels, steps 9 / 23) + a button slicer on it
(colors step 17) instead of the buttons; then the bookmarks, their buttons and the extra visual copies are deleted.
- Keep the most complete copy (column widths, CF, totals, sort, visual filters — `preserve` rules) and carry over
  per-copy differences: an extra code column → the name → code levels (step 18 rule 3); two row levels (group + name) →
  two FP rows with the same value in an extra FP column, the slicer on that column selects both (matrix shows them as levels).
- **Language (⚠️ RULE, user 2026-10-30):** table headers = FP labels, rows per language (flexible, follow `CT_Language`);
  the **button slicer is always Hebrew**: the `Group` column holds the Hebrew name in both language rows, no `Locale
  Match` filter. Reason: a slicer saves the selected text, and Desktop writes the shown value on save — with translated
  group names the saved value is missing in the other language → no button selected, the table loses its row field
  (only totals). Strict single select, saved selection = the default group (Hebrew); `GroupOrder` puts the default first.
- **Not replaced:** bookmarks that open a detail / popup (detail table + back button — a drillthrough page is a separate
  decision), bookmarks that store data (`suppressData` off: filters / slicer states), copies with different measures.
- Scan: `python -I -X utf8 Scripts\ScanBookmarks.py "<X.Report>"` (per page: bookmarks, buttons, switched visuals and
  their fields). Check: values per FP item = the old copy, `CheckReportRefs.py`, `pbir validate`, screenshots; no
  bookmark / button / `visualInteractions` entry left pointing at a deleted visual.
