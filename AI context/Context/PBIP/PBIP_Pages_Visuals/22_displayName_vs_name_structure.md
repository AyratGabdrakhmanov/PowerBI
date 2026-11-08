Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## displayName vs name structure

```json
{
  "name": "SalesYTD",         // ← Power BI looks for this (in the folder name and pages.json), NO spaces
  "displayName": "Sales YTD"  // ← The user sees this in the UI, spaces allowed
}
```

- **name**: technical identifier — must match the folder name on disk,
  no spaces (otherwise Power BI will not find the page).
- **displayName**: human-readable name for the user — free text.
