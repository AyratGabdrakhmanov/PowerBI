Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `CheckReportRefs.py` (added 2026-10-20)

`ClientA\_Documentation\Scripts\CheckReportRefs.py` — read-only: report field references (measures, columns,
hierarchies / levels) that the semantic model does not have — what Desktop shows as broken visuals.

```
python -I -X utf8 CheckReportRefs.py <X.Report> [--model <X.SemanticModel>] [--before <backup X.Report>] [--new-only]
```

- Every report JSON (visuals, pages, filters, bookmarks, `report.json`) is walked as JSON; filter `Source`
  aliases (`From` entries) are resolved; case-insensitive, as in Power BI. `--model` defaults to the sibling
  `X.SemanticModel`.
- `--before` (the report backup taken before an edit, checked against the **current** model) marks each
  missing field `NEW` / `old` and counts the fields fixed since; exit code 1 when anything is NEW.
  One line per field: files count + page display names.
- Difference from `CleanUnused.ps1` Step 10: no deletions, no model analysis, and the before / after split.
- ⚠️ Pass the report as `X.Report` with `--model X.SemanticModel` (ClientB 2026-10-25: run from `definition\` with `..`, the
  sibling model was not found → 168 false "missing" fields, incl. `Items[ItemGroup]`).
- ModelWork 2026-10-20 after the merge: 49 missing fields, NEW 0, all old junk (`Dimension[LoanData_*]`,
  `CollateralData[*]`, `BuybackData[*]`…), 4 fixed (the renamed measures).
