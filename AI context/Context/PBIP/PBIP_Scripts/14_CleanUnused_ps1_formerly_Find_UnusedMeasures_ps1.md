Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `CleanUnused.ps1` (formerly `Find-UnusedMeasures.ps1`)
File: [`ClientA\_Documentation\Scripts\CleanUnused.ps1`](<../../../Scripts/CleanUnused.ps1>). It now
cleans up more than measures — also measures referencing a missing table,
Field Parameters, tables and calculation groups (Step 2b, Step 8 below).
Finds and **immediately deletes** DAX measures that nothing references — without
a separate "report first, then delete" step. Before the first write it
unconditionally copies the **whole** `*.SemanticModel` (not only `definition\
tables\` — it also writes to `cultures\*.tmdl`, `model.tmdl`, `relationships.tmdl`
because of Field Parameter support, see below) to
`ClientA\BackUp\Find-UnusedMeasures_<timestamp>\`.

**`-ThinReports` (version `2026-11-06.1`, user 2026-11-06: some measures are used only in thin reports).**
`';'`-separated list of the model's live-connected thin reports (`*.Report` folders or folders holding one; relative
to `-RootPath` or absolute). Their visuals, filters, bookmarks (raw text — empty cards count too, over-protects only)
and report-level measures (`reportExtensions.json` DAX) count as usage; their files are **never edited** (not in
`$jsonFiles`, which Report.Post edits; usage loops in `Model.ps1` read `$usageFiles` = main + thin). Passed on to
pass 2+. Without it the run prints a yellow WARNING. **Semantic Model — always pass both thin reports:**
```powershell
pwsh -File CleanUnused.ps1 -RootPath "<...\ClientA\Semantic Model>" -ThinReports "..\Collector Assignment\Thin Collector Assignment;..\Collector Assignment\Thin Scorecard"
```
Model (`Model\Model.pbip`): thin report `Report\Risk` (live connection to `Model`) — `-ThinReports "..\Report\Risk"`.
Test 2026-11-06 on a copy of Semantic Model: without thin reports 92 measures deleted, with them 73 — 19 `Tooltip
Scorecard *` measures are used only by the tooltip pages of `Thin Scorecard` (the main report's tooltip pages were
removed 2026-11-06).

**File layout (split 2026-11-02, version `2026-11-02.2`, behaviour unchanged).** You still run only
`Scripts\CleanUnused.ps1`; it dot-sources 5 parts from `Scripts\CleanUnused\`:

| Run order | File | Holds |
|---|---|---|
| main | `CleanUnused.ps1` | params, setup, `-Port` checks, backup, final orphan-translation call, multi-pass self re-run; **all `exit` calls and `$PSCommandPath`** |
| 1 | `Common.ps1` | helper functions (`Get-TmdlConstructs`, integrity check, ...) + 2 regexes `$constructLineRegex`, `$JsonStr` |
| 2 | `Cultures.ps1` | function `Remove-OrphanTranslations` (Step Q removed 2026-11-03) |
| 3 | `Report.Pre.ps1` | Step R (report-side cleanup before the model: frees model objects) |
| 4 | `Model.ps1` | Steps 0-8: qualify column refs, parse model, Field Parameters, usage, measures / calc columns / tables; **all exemptions** |
| 5 | `Report.Post.ps1` | Steps 9-11 (page cards, unused report objects, bookmarks/popups) - after the model deletions |

- Why this order: `Common.ps1` first (functions must exist; Q/R use nothing from it); Step R before the model so that
  model objects it frees are seen as unused in Steps 0-8; Steps 9-11 after, because they depend on what the model
  steps deleted.
- ⛔ **No top-level `exit` in a part:** `exit` in a dot-sourced file does NOT stop the caller (tested). Stops and exit
  codes live only in the main file.
- Exemptions (all in `Model.ps1`): measures in the `Color` display folder; calculated columns using `USERCULTURE`
  (`$cultureColumns`); relationship-key columns; columns whose bare name is in several tables (`$ambiguousBareColumns`);
  tables that **host measures**; Field Parameter tables; `*Time Intelligence*` tables; `LocalDateTable_*` /
  `DateTableTemplate_*`; RLS role tables; `CT_BlankTable` (since `2026-11-02.1`).
- Regression (2026-11-02, copies only; pre-split vs split, `-RootPath`, files closed): ClientB, ClientE Sales Main, ClientD
  Finance, Collector Assignment - exit 0 everywhere, 11 / 3 / 2 / 97 files changed, **0 files differ old vs new, 0
  log lines differ**. Scratch: `RegressCleanUnused.ps1`; to repeat after any edit of a part, copy the pre-edit script
  as "old" and compare MD5 of every result file.

⛔ **Measures in the `Color` display folder are never deleted (user rule
2026-10-15, version `2026-10-15.1`).** They are a palette kept on purpose
(`Grey`, `Blue Vivid`, …) — the script adds every measure whose
`displayFolder` is `Color` or `Color\…` to root usage, so they and anything
they reference always count as used (log line "Kept unconditionally"). Cause: on
ClientB 2026-10-15 the run deleted 7 unused color measures; the user restored them.
Checked on a copy of ClientB: 10 kept, 0 measures deleted.

**ClientF Sales v2 fixes (versions `2026-11-01.1` / `.2`).** A run on Sales v2 (copy of Sales Channels) left a
PBIP Desktop could not open ("Translation in culture … refers to an object which cannot be found") and cut features:
- **Cultures with LF endings:** `Test-TmdlIntegrity` treated every bare LF as damage, so all translation cleanups were
  SKIPPED (one red line in a long log) while the objects were deleted. Now bare LF is accepted when the file on disk
  already has them. + **final sweep every pass** (`Remove-OrphanTranslations`): drops the translation of any table /
  column / measure / hierarchy / level no longer in the model; an entry it cannot remove is an `ERROR` line.
  ⚠️ Before `2026-11-03.2` the sweep read a table's name from the file's first line only, so a table `.tmdl` starting
  with `///` description lines counted as missing and its **whole** translation block was dropped (ClientC 2026-11-03:
  9 live tables, restored). Reports cleaned with an older version: compare the `cultures\*.tmdl` table blocks with the backup.
- **Drillthrough fields** (`howCreated = Drillthrough` on a drillthrough page) are never "empty page filter cards"
  (8 fields of DT Sales Analysis were deleted).
- **Popups of dead bookmarks are kept:** hidden visuals on a page whose buttons call a missing / just-deleted bookmark,
  or named in any bookmark (dead ones too), stay with a `WARN … re-link it` line. Old bookmarks may name visuals by
  pre-PBIR ids, so the button check is the main signal. Before: 24 dead bookmarks → 9 Salespersons commission /
  document popups → their measures (`Commission Calculated` …) deleted.
Check on a copy of Sales v2: 0 SKIPPED, 0 orphan translations, 9 drillthrough fields kept, popups + `Commission
Calculated` kept, Desktop opens it, 0 objects in error after Calculate. Use page by page in a rebuild: run it only after
all pages are settled.

**Relationship-key columns count as used (version `2026-10-28.1`, ClientC).** A calculated column that is the
`fromColumn` / `toColumn` of any relationship (active or inactive) is never a deletion candidate, and column cleanup
(Step 7b) no longer touches `relationships.tmdl`. Before, a key column with no DAX / report use was deleted together
with its relationship (ClientC `Sales NEW`: `Customers[קוד סוכן]`, `Items[Tbl_Family.קוד אב]` — the `TargetFamily`
keys). Unused tables still go with their relationships (Step 8, `Remove-TablesCompletely`). ClientC copy: old version
deleted those 2 columns + 2 relationships; new — 0 columns, 0 relationships, all else identical.
Version `2026-10-28.2`: no `Value cannot be null` error on a model without Field Parameters (ClientC copy: clean log).

**`-Port N` — the report is open in Desktop (version `2026-10-17.1`).** Without it the script only
edits the files: with Desktop open, the bridge apply picks up the report edits but **not** the model
deletions, and the next Ctrl+S writes the deleted tables/measures/columns back (ClientB 2026-10-15 and
2026-10-17). With `-Port` (port — `QueryOpenModel.ps1 -ListInstances`) one run does everything:
checks that the port is this model and saves Desktop if it has unsaved changes (before the backup) →
the usual run on the files → bridge apply (report) → TOM removes from the open model every
relationship / measure / column / table / Q&A blob that the run removed from the files (backup vs
files) → Ctrl+S → checks that none of them came back in the saved files. The Desktop process is found
by the `.pbip` path (`-DesktopPid` if that is ambiguous). Never closes Desktop.
```powershell
pwsh -File CleanUnused.ps1 -RootPath "<...\ClientB\Report>" -Port 60853
```

**Step 8 — two loose spots tightened (version `2026-10-17.2`, ClientB).** Both kept unused tables:
- only a table that **hosts measures** is excluded, not any table **named** `*Measure*` (`MeasureTable` — an
  "Enter data" list of measure names, no measures, used nowhere — was never checked);
- the bare-word fallback (table name anywhere in other DAX/M) skips `"..."` string literals and
  comments (`--`, `//`, `/* */`): `MAX ( Items[ItemGroup] ) = "הובלה"` (an item-group name) and
  `-- הובלה / other` kept the unused table `הובלה`. M `#"Query Name"` is an identifier, kept as usage;
  it is matched as its own token — skipping only its `#` made its closing quote open a bogus string
  and inverted inside/outside for the rest of the text (the first try of this fix missed `הובלה`).
  `Table[...]` references still count everywhere, comments included.
ClientB copy: the same deletions as before plus `MeasureTable` and `הובלה`, pass 2 — nothing.

**Table name read from any line (version `2026-10-23.1`, ClientD Finance).** A table with a description has
`/// …` lines before `table <Name>`; the name regex was anchored to the start of the file, so such tables got an
empty name (`-Port` check failed: "tables on disk missing there: " with an empty list). All five name regexes
now use `(?m)^table`.

**Three wrong deletions / a crash fixed (version `2026-10-23.2`, ClientD Finance).** The `-Port` run deleted used
measures and then failed half-way (the model was restored from the backup):
- **JSON escaping** — report names were compared as written in the file: `Credit\Debit balance` is
  `"Credit\\Debit balance"` in JSON, so two measures used by 6 visible visuals counted as unused. Report captures
  (measure / column / alias patterns) are now JSON-unescaped (`ConvertFrom-JsonStringBody`), and table names searched
  in report text are JSON-escaped first (`ConvertTo-JsonStringBody`).
- **Nested DAX comments** — DAX block comments nest (`1 /* a /* b */ c */ + 1` = 2). `Remove-DaxComments` (Step 2b
  "references a nonexistent table") was a non-greedy regex that ended the outer comment at the inner `*/`;
  `[Cumulative Balance]` had `'Date&Periods'` only in nested comments and was deleted although used. Now a character
  scanner: nesting depth, `"strings"` skipped (`//` inside a string is not a comment).
- **`|` in a table name** — `Sync-OpenModel` kept removed members as `"Table|kind|Name"` and split on `|`; the table
  `P&L|Balance Sheet Labels` broke the split, `$coll` was `$null`, the TOM step stopped. Members are now objects.
- Also seen in that run: the bridge apply removed the deleted tables / measures from the open model by itself
  ("Semantic model out of sync" in Desktop) — see `AI_Tools_MCP_CLI.md` → `powerbi-desktop reload`.
Checked on a copy of Finance: the three measures are kept (used 88, was 85), 0 "uses missing" warnings, the cleaned
TMDL loads (`ValidateTmdl.ps1`).

**Step 11 — unused custom visuals (version `2026-10-23.4`, user request).** A custom visual is registered in
`report.json`: AppSource ones in `publicCustomVisuals` (visual GUIDs), imported `.pbiviz` ones as a `resourcePackages`
entry of `type: CustomVisual` plus the folder `<X>.Report\CustomVisuals\<name>\`. Used = its GUID / package name appears
as `"visualType"` in any `visual.json` or `*.bookmark.json` (bookmarks keep visual states with their type), checked after
Steps R / 10 removed hidden visuals. Unused ones are removed from `report.json` (and the package folder). Not counted for
extra passes. Finance copy: `Slicer1448559807355`, `charticulator…`, `ChicletSlicer1448559807354` (AppSource, no visual)
removed, nothing else in `report.json` changed; synthetic test: an unused imported package + folder removed, a used one kept.

⛔ **Rule (user, 2026-10-23): run `CleanUnused.ps1` only with the report CLOSED — files only, no `-Port`.** Close the
report without saving (files on disk = the wanted state), run, `ValidateTmdl.ps1`, then `powerbi-desktop open` the
`.pbip` — data comes from `.pbi\cache.abf`, no refresh (Finance: 33 tables / 88 measures loaded with data). Why: on the
MSI Desktop (`C:\Program Files\…`) both `-Port` runs desynced — the bridge apply removed objects by itself, and
Ctrl+S wrote Desktop's full in-memory model over the cleaned TMDL, ignoring the TOM deletions. Version `2026-10-23.3`
still fixes two `-Port` defects for the record: `$coll = if (…) { $tbl.Measures } …` enumerated the collection
(`Find` missing → no measure / column was ever removed via TOM; now a plain assignment), and `-SkipInitialSave`
(Desktop flags "unsaved" right after open / apply and Ctrl+S then writes nothing).

**Step Q — removed 2026-11-03 (version `2026-11-03.1`, user):** it deleted the Q&A `linguisticMetadata` from
`cultures\*.tmdl`, but Desktop regenerates it on every save, so it is no longer touched (`PowerBI_Options.md`).

**Step 10 (2026-10-13, versions `2026-10-13.2`–`.3`) — junk from old model versions,
from the first run.** Found on ClientB: after the regular cleanup there remained 138
references to non-existent tables/fields (`Targets`, `תאריכים` — "dates",
`DateTypeToChooseFrom`, `מימד מתחלף` — "changing dimension", measures
`...ByDocDate`, `ETL_SA_IncomeFromACC_41004`) and ~1,000 dead formatting
entries; they were removed manually in three passes, now Step 10 does it:
- **10a — visual formatting** (`visual.objects.<card>[i]`):
  an entry is deleted if it contains a field that does not exist in the model (for example,
  conditional formatting icons on `Targets[...]`), or if its selector is
  only `{"metadata": X}` and `X` is not the `queryRef` of any field of the visual
  (width/format of a column already removed from the visual). On ClientB — 1,071
  entries (885 widths, 156 formats, 51 icons on `Targets`); none of them
  related to a field present in the visual under a different `queryRef`.
- **10b — a hidden visual** (itself or its group) with a field that does not exist in
  the model is deleted together with the page's `visualInteractions` and its state in
  bookmarks (`Charges` on `Page8` — a row from the deleted table
  `ETL_SA_IncomeFromACC_41004`). A **visible** visual of this kind — only `WARN`.
- **10c — bookmarks:** saved filters (`byExpr`, `byName`) and sorts
  (`singleVisual.orderBy`) on missing fields are deleted; the states of
  visuals deleted in 10b, and their names in `options.targetVisualNames`, too.
  Anything broken that remains outside filters/sorts — `WARN`. On ClientB — 327
  items (321 filters, 4 sorts, 2 `Charges` states).
  **Since version `2026-10-13.3` — also "dead tails":** the state of a visual
  that no longer exists on its page, and a section for a page that does not exist (unless
  it is the bookmark's `activeSection`), are deleted. Behavior does not change — on ClientB
  all 28 such states only kept an already deleted hidden visual hidden.
  Side effect on ClientB: the tail `Page10/pivotTable3` (the bookmark `customer
  comper` "showed" it) protected from Step R four hidden `pivotTable3` on
  pages 12–15 that no bookmark showed on their own pages
  — after the tail cleanup, Step R deleted them (verified: not used).
- **Navigation warnings (Step R, version `2026-10-13.4`, WARN only,
  changes nothing):** (1) a `<X>On` tab leads to a different bookmark than
  its `<X>Off` pair (pattern and cause — "On/Off tab buttons" in
  `PBIP_Pages_Visuals.md`); (2) a **visible** button whose bookmark opens
  another page (`activeSection` ≠ the button's page). Verified on ClientB: on the
  copy before `Page2` was fixed, all 5 tab mismatches were found; on the current one —
  another 7 on `Page3`/`Page10` and 5 visible buttons leading to another page.
- ⚠️ **Step R checks "shown via a bookmark" by visual name, without the page** —
  left that way on purpose (conservative: the extra match only keeps things). An exact
  "page|visual" check on ClientB would delete another 45 hidden visuals
  (On/Off tab buttons and helper matrices on pages 4, 8, 10,
  12–17 — looks like copied navigation). This is the user's decision,
  not a silent cleanup; the list is in the history of the 2026-10-13 session.
- The field check is the same as in Step 9 (case-insensitive, as in Power BI:
  `groupcode` = `GroupCode`). Files are rewritten via `ConvertTo-Json`
  (2-space indent, as in `RenameObjects.ps1`), only if something
  changed.
- **Verified 2026-10-13:** a single run on a copy of ClientB from before the morning cleanup gave
  the same result as the three manual passes (comparison by content of all
  499 report files); the only difference is the empty `"filterConfig": {"filters": []}`,
  which Step 9 leaves after deleting the last card and which Desktop
  removes on save. A repeat run deletes nothing.

**How "used" is determined:** report/page/filter/sort/
conditional formatting in `.Report` (see below on the JSON form), a calculated
column/table, a calculation group's `calculationItem`, or another measure
that is itself used (graph traversal — an entire chain of measures referencing
only each other with no live root is found and deleted in one piece).
Reference detection inside DAX is by a bare `[Name]` without a table qualifier
(= a measure, per this project's convention from `BPARules_ClientA.json`: columns are always
`Table[Col]`/`'Table Name'[Col]`, measures never have a qualifier) — this is
**not a real DAX parser**, but a heuristic relying on that convention.

⚠️⚠️ **Incident 2026-09-13 — three blind spots of the heuristic found in
practice**, because of which the first run **deleted 475 measures, 30 of which
were actually in use**:

1. **Field Parameters and `NAMEOF`.** The model has several Field
   Parameter tables (`Dynamic Numeric Parameter`, `FP`, `FP_Categories`,
   `FP_D-M-Q-Y`, `FP_Dynamic_Range_Parameter`, `FP_JournalEntries`,
   `FP_Measure`, `FP_Period`, `FP_RowDetails`, `FP_Y-Q-M-D`, `Parameter`) —
   their calculated-table DAX lists measures via `NAMEOF(...)`. But Power BI
   Desktop generates **both** forms mixed together: `NAMEOF([Name])` (bare,
   caught by the general rule) AND `NAMEOF('Measure'[Name])`/
   `NAMEOF(Measure[Name])` (with a table qualifier — the same form as
   a regular COLUMN reference, which is why the old rule "qualified =
   not a measure" discarded it). Fix — `Get-BracketRefs` separately catches
   the qualified form specifically inside `NAMEOF(...)`, but does not change the general
   rule for the rest of DAX.
2. **The measure is physically stored outside the `Measure` table.** 17 tables in the model
   hold "their own" local measures (`Excel`, `CollectorAssignmentSnapshot`,
   `CT_ReportType`, `JournalEntries`, `CT_Delinquency_table`,
   `DealerGradeHistory` and others). In visual/filter JSON a reference to such a measure
   looks like `"Measure": {"Expression": {"SourceRef": {"Entity":
   "<host_table_name>"}}, "Property": "MeasureName"}` — `Entity` is **not**
   equal to the string `"Measure"`; it holds the host table's name. The sign "this is a measure, not
   a column" is the JSON key `"Measure"` itself (as opposed to `"Column"`), not the
   value of `Entity`. The old pattern required `Entity == "Measure"`
   literally (a generalization from a single example that happened to live in the
   `Measure` table) — because of this, **all** references to locally
   stored measures were missed, including `"Show Existing CollectorAssignmentSnapshot"`
   (a visual-level filter measure, actually used in 93 files).
   Fix — the main pattern is now anchored on the JSON key `"Measure"`; the value of
   `Entity` inside is not restricted.

The first two fixes are in the script itself (`Get-BracketRefs`, `$reportUsagePatterns`),
not a one-off patch. **Restoring what was deleted without a backup** was
possible this time only because the user happened to have a separate manual
copy of the model — we built the usage graph from that backup with the already fixed
heuristic, took the intersection "used" ∩ "missing from the current
model" (30 measures, not all 475), and copied the measure blocks back one by one. No one-off
script was created for this (see below).

3. **An orphaned translation (`caption`) breaks loading of the WHOLE model, not just
   Q&A.** The project also keeps a copy of this script in a separate PBIP project
   `Collector Assignment\Report\` (not only in `ClientA\Model\`) — the same run
   there deleted the measure `Sales # Per Dealer` (correctly, it really was not used),
   but did not touch its `caption` entry in `definition\cultures\en-US.tmdl` inside
   the TMDL-native block `translations > model Model > table Measure > measure
   'Name' > caption: ...`. This block is a **strongly typed** `Translation`
   object, not lenient JSON (unlike `linguisticMetadata` — the large
   JSON block of Q&A synonyms a little further down in the same file, with fields
   `"State": "Generated"`, which Power BI Desktop does tolerate being
   stale). An orphaned `caption` entry breaks loading of the **whole** project
   in Power BI Desktop with the error `Cannot resolve all the paths while
   de-serializing Database... Property Object of object "Translation in
   culture en-US" refers to an object which cannot be found` — without indicating
   which measure is to blame (it was found by checking every measure in the `translations` block
   against the table's current measure list). Fix — a new step in the script itself
   (after deleting measures): it scans **only** the header part of
   `cultures\*.tmdl` (up to `linguisticMetadata =`) and cuts out `measure 'Name' /
   caption: ...` for each deleted measure, by indentation boundary (the next
   line with indentation ≤ the `measure` indentation ends the entry). `linguisticMetadata`
   is deliberately left untouched (no evidence has been found yet that it needs
   to be cleaned up as strictly).

**Field Parameter tables (since 2026-09-13).** The same "find and immediately
delete" principle, applied to whole tables rather than individual measures — a separate step
after deleting measures (the same unconditional backup covers both).

- **Detection — by shape, not by a list of names.** A Field Parameter is a
  calculated table whose `partition ... = calculated` contains `NAMEOF(...)`
  in its source DAX (this is exactly how Power BI Desktop generates such tables) —
  this catches both the existing ones (`FP`, `FP_Categories`, `FP_D-M-Q-Y`,
  `FP_Dynamic_Range_Parameter`, `FP_JournalEntries`, `FP_Measure`, `FP_Period`,
  `FP_RowDetails`, `FP_Y-Q-M-D`, `Parameter`, `Dynamic Numeric Parameter`) and
  any new ones that appear later.
- **Exception — the Calendar table, at the user's explicit request.** If
  AT LEAST ONE `NAMEOF(...)` entry inside the table references `'Calendar'[...]`
  — the whole table is excluded from deletion unconditionally, regardless of the
  usage check result. In practice these are not only pure date-grain
  switchers (`FP_D-M-Q-Y`/`FP_Y-Q-M-D` — switching between
  `Calendar[Date]`/`[Month Year]`/`[Quarter Name]`/`[Year]`), but also mixed
  tables like `FP_Categories` — there 12 of 13 options reference
  `LoanData`/`DealerData`/`AutoCount`, and only one ("Origination Year") references
  `Calendar[Year]` — that one item is enough to protect the whole
  table.
- **"Used" — not the same graph as for measures.** A Field Parameter is not
  called from other measures' DAX in the same way a measure references a measure —
  it appears in a visual as a regular column field. The check is a pass through the whole `.Report`
  of the same thoroughness (not only the obvious places), but with a
  different signal: `"Entity": "<TableName>"` anywhere (Rows/Values/Legend,
  slicer, filter, sort — equally at visual/page/report level).
  No chain/graph traversal — the presence of `Entity` at table level is
  the whole check.
- **Deleting the table completely:** the `.tmdl` file itself, the `ref table` line in
  `model.tmdl`, any `relationship` blocks in `relationships.tmdl` where
  `fromColumn`/`toColumn` points to the table being deleted, and its `table 'Name'`
  entry in the `translations` block of `cultures\*.tmdl` (the same principle as for
  measures above — `linguisticMetadata` is not touched). `diagramLayout.json`
  (the box position on the relationships canvas) is deliberately not cleaned — cosmetic.
- **Verified in practice (2026-09-13, `Collector Assignment\Report\`):** of
  11 Field Parameter tables, 4 were excluded (Calendar-related); of the remaining
  7, 4 turned out to be unused anywhere (`Dynamic Numeric Parameter`,
  `FP_Dynamic_Range_Parameter`, `FP_Measure`, `FP_RowDetails`) and were deleted;
  `FP`, `FP_JournalEntries`, `Parameter` are used and were kept. An important
  nuance: `Dynamic Numeric Parameter` was deleted as a table only AFTER
  three of its measures (`Borrower Age`, `Months On Book Avg`, `Recourse`) had been
  restored in a separate incident analysis (see above) — the selector table
  itself was not needed by anyone, but the measures it listed
  turned out to be needed for a completely different reason (see the example analysis of the
  `[BB]` chain in the session history) — deleting a Field Parameter does NOT mean that the measures
  inside its `NAMEOF(...)` are not needed either; these are independent facts.

**⚠️ The order of steps matters: Field Parameters → measures → Step 2b → Step 8, not
any other way.** `NAMEOF(...)` entries inside a Field Parameter are a source of
"used" for measures (for example, `FP_Measure` lists `[BB Net %]` →
`BB Net %` is alive → transitively `BB Net` → `BB LaterMonth` → `BB`). If
measure usage is computed using a Field Parameter that will itself be
deleted by the same run as unused — the decision ends up based on a
source that will no longer exist by the end of the run. This is exactly what happened when
FP and measures were first split into two independent passes: `BB Net %`/`BB
Net`/`BB LaterMonth`/`BB` survived the run that deleted `FP_Measure` (their
only reason to count as used), and were orphaned until the next
run. Fix — analyzing and deleting Field Parameters FIRST, excluding
the deleted FP constructs from the measure usage root before the measure analysis starts —
closes this in a single run.

**Step 2b — a measure referencing a missing table (since 2026-09-13, at the
user's explicit request).** `Collector Assignment\Report\` is a confirmed,
intentionally **narrow** report in which some tables of the
full model are entirely absent (`LoanData`, `AutoCount` — confirmed by the user,
"CollectorAssignment — narrow, specific report", do not assume in advance).
If a measure references a table that does not exist in the model at all
(`Table[Col]`/`'Table Name'[Col]`) — the measure is deleted **regardless of
usage status**: since it cannot be evaluated, being present in a
visual does not save it. Detection — for each measure ALL
qualifying table names are extracted from its DAX (`Get-QualifiedTableRefs`)
and compared with the list of actually existing `table X` in `definition\
tables\`. Such a measure stays on the "to delete" list, but is removed from
the "can be a usage root" list — otherwise its own
(broken) reference to another measure could still artificially
"save" that measure. Known limitation: it only catches the measure's OWN direct
reference to a missing table — if measure X (itself
working) references measure Y, which is deleted by this rule, X
will be left with a dangling reference to a non-existent measure after Y is deleted,
which this check does not catch (that is a reference to a MEASURE, not a table) —
it requires manual analysis if suspected.

**Step 8 — unused tables and calculation groups (evolved over
several iterations, 2026-09-13, at the user's explicit request).** The same "find
and immediately delete" principle, applied to whole data tables and whole calculation
groups (`calculationGroup`), not only to measures/Field Parameters —
it runs LAST, after measures and Field Parameters in the same
run have already been finalized.

- **"Used"** — a qualitatively different, MORE strict check than for
  Field Parameters: `"Entity": "<Name>"` anywhere in `.Report` (the same signal
  as for Field Parameters) **OR** any OTHER surviving DAX construct
  (measure/calculated column/calculated table/`calculationItem`)
  references it — qualified (`Table[Col]`/`'Table
  Name'[Col]`) or by the bare table name as a whole (`ALL(Table)`,
  `VALUES(Table)`, `CALCULATETABLE(...)` etc. — by the bare word,
  deliberately loose: a false "used" here only means extra
  protection, never a wrong deletion). The table's own constructs
  are excluded from the search (otherwise a single-word name like `parPTI` would always
  "find itself" inside its own line `partition parPTI =
  calculated`).
- **The existence of a relationship (`relationship`) does NOT by itself count as
  "used"** — a relationship matters only if something actually
  reads a column through it (a DAX reference, `USERELATIONSHIP`, or a column of the
  table physically placed in a visual/filter/slicer). Found on a specific
  example from the user: `DealerData` (3 relationships, but NOT a single DAX reference, NOT
  a single `"Entity"` in `.Report`) — it used to survive only thanks to its relationships,
  now it is correctly considered unused, and its relationships are deleted together with
  the table (`Remove-TablesCompletely` could already clean up relationships; only
  the "used" criterion had to change).
- **Calculation groups (`calculationGroup`) — used to be fully excluded,
  now they are full candidates for deletion (at the user's explicit
  request: "checks are the same as for unused measures").**
  They are identified structurally, by the `calculationGroup` keyword inside
  the table — NOT by the `CG ` prefix naming convention, which is only
  a habit in this project, not a fact. There are 10 of them in the model:
  `CG Dynamic Format`/`CG Journal Entries`/`CG Time Intelligence`
  (with the prefix) + `AutocountTargetDealer`/`Buyback`/`CreditSummary`/
  `DateContext`/`LoanCriteria`/`Operational`/`Time` (without the prefix — exactly
  this inconsistency caused the incident below). The only
  unconditional exception (at explicit request): any table/group named
  `*Time Intelligence*` is never deleted, regardless of usage
  status (the same logic as the Calendar exception for Field
  Parameters in Step 2).
- **⚠️ Incident: incorrect detection of calculation groups led to the deletion of
  5 that were actually in use.** Before structural detection, calculation groups
  were protected from deletion only by lucky coincidence with one of the
  regular checks — 5 of the first 6 tables that Step 8 ever deleted
  (`AutocountTargetDealer`, `CreditSummary`, `LoanCriteria`, `Operational`,
  `DateContext`) turned out to be calculation groups without the `CG ` prefix;
  they were restored from backup. A calculation group is applied via
  `SELECTEDMEASURE()`/`SELECTEDMEASURENAME()` to a measure already placed in the visual
  — it does not need its own placement as an `"Entity"`, so none of the
  regular checks can reliably tell whether it is used. This risk
  did not go away after calculation groups became deletable —
  a group applied ONLY via `SELECTEDMEASURE()`/
  `SELECTEDMEASURENAME()` (never named literally, never
  placed as an `"Entity"`) is invisible to all checks and can be
  deleted by mistake — the CAVEATS section in the script output explicitly warns about
  this; the final list should be checked against your own knowledge of the model.
- **⚠️ A side incident from the same analysis: false self-match on a bare
  word.** `parPTI` (and other single-word `par*` tables) showed as
  "used" even though nothing else referenced them — because
  the search included the table's OWN construct (`partition parPTI =
  calculated` trivially contains the word "parPTI"). Fix — the search now
  always excludes the constructs of the table being checked.
- **⚠️ Incident: `calculationItem` inside a calculation group was never
  parsed.** A calculation group's DAX (`calculationItem`) is nested TWO
  tabs deep (`table X` → `calculationGroup` → `calculationItem`), not one,
  like `measure`/`column`/`partition` directly under `table X`. The old regular
  expression of the construct parser required exactly one tab — `calculationItem`
  was NEVER found, in any calculation group in the model, since this check was
  introduced. This meant that calculation group DAX (for example,
  `DateContext`'s `USERELATIONSHIP(PaymentData[PaymentDate],
  'Calendar'[Date])`) was invisible both to the measure usage root (Step 3) and
  to the "used" check of other tables (Step 8) — discovered while
  analyzing why `parVehicleAge`/`parMileage`/`parLTV`/`parPTI` survived
  the run: `LoanCriteria` (a calculation group) contains bare bracket references
  like `[parVehicleAge Value]` — by project convention this is a reference to a MEASURE,
  but there is no measure with that name ANYWHERE, neither in this model nor in `Model_v2`
  (it looks like a reference that was broken from the start inside `LoanCriteria` itself,
  unrelated to the script) — nevertheless the loose bare-word match
  counted it as usage of the TABLE `parVehicleAge`. Fix — the construct
  parser now allows `\t*` (zero or more tabs) instead of
  a fixed single one, which covers both nesting levels at once.
- **⚠️ Incident: the "used" check was single-pass, not a fixed-point
  iteration — mutual protection of two doomed tables.**
  `CompetitorHouseDealer` referenced `CT_ExcludeLenders[Lender]`, but was itself
  deleted as unused in THE SAME run — however, the static
  single-pass computation had already recorded the DAX of `CompetitorHouseDealer`
  as live protection for `CT_ExcludeLenders` before both were
  struck out, so `CT_ExcludeLenders` survived an extra run without
  any real reason — the same form of error as the original bug with
  the Field Parameter/measures order (see above), only between two regular
  tables. Fix — the check now runs to a fixed point: each
  pass excludes the constructs of candidates already confirmed as unused
  from the search for all remaining ones, and repeats until a pass
  stops finding anything new.
- **⚠️ Incident 2026-10-06 (ClientE `Sales Main`, version `2026-10-06.1`) —
  three gotchas in one run; the model would not have opened after it** (rolled back from
  backup, script fixed, repeat run clean):
  1. **RLS roles were not scanned** → `RLS_Agents` was deleted (no report usage, no
     DAX — only a `tablePermission` in `roles\*.tmdl` and a relationship), and both roles
     were left referencing a non-existent table. Fix: `roles\*.tmdl`
     are read; the table from `tablePermission` and everything the filter DAX reads
     (tables, measures, columns) count as used unconditionally.
  2. **Auto date tables were deleted** (`LocalDateTable_*`,
     `DateTableTemplate_*`) — but the `variation`/`defaultHierarchy` of the columns
     referencing them were left dangling (9 of them). Fix: such
     tables are excluded from candidates unconditionally; to remove them — turn off Auto
     date/time in Desktop.
  3. **Step 2b ("reference to a non-existent table") read comments** —
     `New Customers`/`Sales Last Period` (used in the report) were deleted
     because of old code `/* … DocsSales[DocDate] … */`. Fix: in step 2b the DAX
     is taken without `/* */`, `//`, `--` (only there — in the usage
     check comments are still taken into account, which is the safe
     side).
- **Step 9 — empty filter cards in the report** (since version `2026-10-06.3`,
  at the user's request). Removes from the `filterConfig` of visuals/pages/
  `report.json` (not bookmarks) cards **without a condition** (no
  `"filter"` key) if the field: (a) does not exist in the model (measure/column/
  table — leftovers of an old model version, shown in Desktop with a warning
  icon), or (b) for visuals only — exists, but is not
  used by the visual itself (not in projections/sortDefinition) —
  leftovers of earlier development. A card **with a condition** is not touched —
  `WARN` for manual review. The JSON is edited as text (the card object
  is cut out by its brackets); the rest of the file stays byte-for-byte the same. The backup now
  also copies `*.Report`. ClientE `Sales Main`, 2026-10-06: 29 cards on
  missing fields + 66 on unused ones.
  **Since version `2026-10-15.2` (ClientB, by request — the logic of `CleanReportFilters.py`):**
  also removes **page-level** empty cards on existing fields when the Filters pane is hidden
  from viewers (`report.json` → `objects.outspacePane.visible = false`; if visible → `WARN`,
  kept) and no bookmark gives that card a condition; Step 10c then removes the
  condition-less bookmark entries of those cards. Test on a ClientB copy: 28 cards on 8 pages,
  55 bookmark entries in 9 bookmarks — the same as `CleanReportFilters.py`.
  **Version `2026-10-15.3` — one pass again.** In `.2` table `Projects` was deleted only in
  pass 2: the empty page card `Projects[ProjectName]` was already not usage, but its
  condition-less **bookmark entries** were (bookmarks were read as is), and Step 10c removed
  them after Step 8 had decided on tables. Now `$usageText` drops bookmark filter entries
  without a condition (`byExpr` items / `byName` entries without `"filter"`, at bookmark,
  section and visual level) — they filter nothing; everything else in a bookmark still counts.
  ClientB copy: pass 1 deletes `CT_SurplusFilterMode`, `CustomersSmall`, `Projects`, measure
  `KeyData[SubItemCode Shortest Name]` and calc columns `Items[SubItemCode Combined Display
  Name]`, `Items[IsMainItem]` (all held only by empty bookmark entries on Page8 / Page11
  pivots; `IsMainItem` only by that measure); 59 bookmark entries in 13 bookmarks; pass 2 —
  nothing left.
- **One run does everything (version `2026-10-06.5`).** Empty filter cards
  **do not count as usage** at any analysis step (Field
  Parameters, measures, columns, tables read the report via `$usageText` — JSON
  without empty cards; bookmarks — as is), so a measure held
  only by such a card is deleted in the same pass, and step 9 also removes the
  card. One rare case remains for a second pass — a calculated
  table deleted by step 8 whose DAX held a measure (`Targets_YTD`); for that the
  script relaunches itself on the same files (without a new backup) until
  a pass deletes nothing (at most 10). Final test 2026-10-06 on two
  states: the first run deletes everything (control 2nd pass — 0),
  a repeat run does not change a single byte (545 and 408 files), dangling
  fields in the report — 0. Bookmarks count as usage — a measure living
  only in a bookmark is kept (otherwise the bookmark would break).
- **Step R — report cleanup, BEFORE model analysis** (version `2026-10-06.7`, at
  the user's request; ClientE `Sales Main`: all 24 bookmarks pointed to
  non-existent pages — copied/deleted OLD pages).
  Deletes: (R1) a bookmark whose page (`activeSection`) does not exist;
  (R2) a bookmark that no button/navigator calls (neither its name
  nor its group's name appears in `pages\`) — ⚠️ a bookmark meant only for the
  Bookmarks pane in the Service will also be removed; (R3) **a hidden visual that is not
  used**: no remaining bookmark shows it AND it is not a
  slicer working while hidden (its saved selection filters the page, or it is in a
  sync group) — such a visual is KEEP together with its parent groups.
  Child visuals of a group being deleted go with it, `visualInteractions`
  in `page.json` are cleaned, `bookmarks.json` is rebuilt. A visible button
  pointing to a non-existent bookmark — only `WARN`. The script **does not retarget**
  a bookmark to a new page (it does not know where to) — it will delete such a bookmark;
  if it is needed, retarget it manually BEFORE the run (this was done with
  SHOWPOPUP/HIDEPOPUP/עמלותpopup on "דוח סוכנים"). Hidden filter cards
  WITH a condition are never touched (step 9 deletes only empty ones).
