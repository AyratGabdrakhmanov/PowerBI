Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 9. He / En translations

ClientB pattern (`PBIP_Recipes.md` → translations): `CT_Language` switcher, he-IL + en-US captions on every visible
field and table, language measures for titles / labels, manual visual names win (`pin_display_names.py`).
- **Slicer titles** (user 2026-10-28): every slicer — header off, title on and centred, `title.text` = hidden measure
  `'Slicer <Name>'` (display folder `Labels`, `COALESCE ( [Selected Culture], USERCULTURE () )` + `SWITCH` He / En), never a
  literal. Rule `BP_MANUAL_SLICER_TITLE_LANGUAGE_MEASURE`, recipe `PBIP_Recipes.md` → "slicer names". Needs `CT_Language`.
- **Agent names He / En** (user 2026-10-28, every project; ClientC pattern): `Salespersons[SalespersonName]` stays the
  Hebrew data column (slicers, filters, bookmarks, RLS — saved Hebrew values keep matching); + hidden
  `SalespersonName_En` = `COALESCE ( LOOKUPVALUE ( 'CT_ValueTranslation'[En], …[Key], "Agent", …[He], [SalespersonName] ),
  [SalespersonName] )` (folder `_En`) + hidden `'SalespersonName Display'` (`expressionContext: userContext`, same culture
  check as the `CT_` columns, folder `_Trans`); tables / charts / matrices show `Display`, slicers stay on the Hebrew
  column. `CT_ValueTranslation` (Key / He / En, hidden DATATABLE): a new agent = a new row (missing → shown in Hebrew);
  English names drafted from SAP names, the client reviews them. Needs compatibility level ≥ 1705 (one-way) and
  `CT_Language`; gotchas (no iteration over the whole table, hierarchy levels) — `PBIP_Recipes.md` → culture
  translation columns.
