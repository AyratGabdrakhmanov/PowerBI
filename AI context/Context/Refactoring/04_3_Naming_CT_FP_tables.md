Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 3. Naming: `CT_` / `FP_` tables

Rules `BP_CALCULATED_TABLE_PREFIX_CT` (DAX tables → `CT_…`, calendars excepted), `BP_FIELD_PARAMETER_PREFIX_FP`,
`BP_FIELD_PARAMETER_COLUMN_FP`, `BP_CT_LANGUAGE_HIDDEN`. Names by substance; no `/` or spaces.
- Model: TOM rename + partition name; rewrite DAX refs explicitly (`'Old'`, unquoted `Old[` / `Old)`); captions stay.
- A DAX table that only holds measures → move the measures to `_Measures` (TOM: captions off → Clone → Remove → Add →
  captions back; keep them hidden if the old table was hidden), delete the table.
- Report: `ReportFields.py replace --from Old --to New` (columns, rename mode) + `MoveMeasureRefs.py` (measures);
  then check leftover `From` aliases of the old entity and that every report field exists in the model.

**Power Query = navigation (+ typing) only** (user rule 2026-10-27): no transformation steps (filters, joins, merges,
replace, added / removed / renamed columns, column choice, distinct, sort). Rows, columns and calculations go into the
SQL (Power Loader); renames into the model (`sourceColumn` mapping); typed-in data into DAX `DATATABLE` tables. The model
columns = the SQL output columns (a shared query with extra columns: keep them, hidden). Exceptions: `_Measures` `#table`,
`Date Last Refreshed`. ClientB: `Refactoring\ClientB\pq_navigation_only.py` (2026-10-27).

**Standard table names (Sales Channels, 2026-10-27):** facts `Sales`, `Purchases`, `Targets`; dimensions `Customers`,
`CustomerProperties`, `Items`, `ItemProperties`, `Salespersons`, `Companies`, `Calendar`, `CT_DocumentType`; selectors
`CT_Currency`, `CT_DocStatus`, `CT_TransactionDateType`, `CT_Language`. Rename tool (model + report + cultures, DAX-aware):
`Refactoring\ClientB\rename_model_objects.py`. Open for all projects: time intelligence as calculation groups.

**Model conventions (user 2026-10-27, reference Sales Channels):** no `ETL_MD_` / `ETL_` prefixes in model table or column names
(SQL names stay only in M navigation and `sourceColumn`); `Server` / `DB` text parameters (query group `Parameters`) in every
`Sql.Database`; Power Query groups `Parameters` (0) / `Fact` (1) / `Dimension` (2); `_Measures` stays the Power Query `#table` of `MeasuresTable.json` (step 1b). Script: `Refactoring\ClientB\model_conventions.py`.

**Measure names English (user 2026-10-27):** every measure name is English; the Hebrew name moves to the he-IL caption
(`cultures/he-IL.tmdl`), so a Hebrew viewer sees no change. Same for renamed tables / columns (Sales Channels names): the
old Hebrew name becomes their he-IL caption. Names by substance, reused from an existing project when it is the same
measure. Closed PBIP: `Refactoring\ClientC\RanNew\measures_english.py` + `captions_he_ran_new.py` (rerun after every rename).

⚠️ **Closed-file renames of import tables (or their M) drop the cached data:** after the reopen every renamed import table
is empty and needs a data refresh by the user (ClientC RAN NEW 2026-10-27). DAX tables come back with `Calculate`. When a
refresh is not possible, rename in the open model via TOM instead (renames keep the data). A table converted from "Enter
data" M to DAX in the files keeps its old (empty) cache storage — `Calculate`, TOM / TMSL `Full` on the table do not
replace it; the user's Desktop Refresh does. `powerbi-desktop reload` does not load model changes made in the files —
close Desktop (no unsaved changes) and reopen the `.pbip`, never save the stale session.

**"Enter data" without data (empty model):** decode the rows from the M itself (`Binary.FromText` base64 → raw Deflate →
JSON rows), apply the query's own steps (remove rows, filters, renames), write `DATATABLE` (ClientC RAN NEW 2026-10-27).

**Row-level "changing dimension" tables** (a DAX table = every fact row × N categories, joined on an M index column) →
field parameter `FP_…` with the same labels (saved slicer selections keep matching), `Sel` copy column for
`SELECTEDVALUE` (user 2026-10-27, ClientC RAN NEW). Needed when the fact SQL has no row key (v3).

**Year-less month filters** (old Hebrew month names on page filters) → `Calendar[Month Name]` dates of the page's single
year; a page without a single year loses the month condition (user 2026-10-27, "reference only"). Tool:
`Refactoring\ClientC\RanNew\calendar_ran_new.py`.
