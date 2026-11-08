# Power BI PBIP Structure and Working with Pages

## 🧰 Catalog: AI + Power BI — approaches, rules, scripts (overview, 2026-10-07)

Entry point to the file: everything we have tried in AI (Claude Code) work with
Power BI, in one list. Details are in separate files (section titles
are given in "quotes"; which section is in which file — see the "Section map" at the end). Links are relative to this file
(`ClientA\_Documentation\Context\`); the common root of all paths is
`C:\Users\ayrat\OneDrive\Документы\`.

### Approaches

| # | Approach | Essence | Details in |
|---|---|---|---|
| 1 | **PBIP/TMDL as text** | The report (`*.Report`, JSON) and the model (`*.SemanticModel`, TMDL) are stored as folders — the AI reads and edits the files directly instead of clicking in Desktop. Works as long as the rules are followed: name synchronization, UTF-8 without BOM, indentation, CRLF in TMDL | "Three critical places to keep in sync", "⚠️ CRITICAL RULES", "Working with `functions.tmdl`/`Measure.tmdl`" |
| 2 | **Checking against the official JSON schemas** | Local copies of the MS schemas — check `page.json`/`visual.json`/theme fields against the schema rather than guessing | [page-2.1.0.json](Schemas/page-2.1.0.json), [visualContainerSchema-2.13.0.json](Schemas/visualContainerSchema-2.13.0.json), [visualConfigurationSchema-2.8.0.json](Schemas/visualConfigurationSchema-2.8.0.json), [reportThemeSchema-2.159.json](Schemas/reportThemeSchema-2.159.json); "`page.json` schema", "`$schema` version of the visual…" |
| 3 | **Theme + Style Presets** instead of local formatting | Formatting is moved from `visual.json` into the theme (`visualStyles`); the visual references a preset | "Report theme and Style Presets", example — [ThemeWarm.json](<file:///C:/Users/ayrat/OneDrive/Документы/ClientA/_Documentation/Reference/Maket/ThemeWarm.json>) |
| 4 | **DAX UDF** (`functions.tmdl`) | Shared logic (e.g. prior-period comparison labels) — one function instead of copies in measures | "DAX User-Defined Functions" |
| 5 | **Recipes + short prompt aliases** | A typical edit is described step by step; a one-line prompt (`Copy navigation to <Page>`) runs the whole recipe | "Recipe: add a new KPI card", "Recipe: [Copy Navigation Buttons]"; example task statement — [Card Promt.txt](<../Other/Card Promt.txt>) |
| 6 | **PowerShell scripts for bulk edits** | Name synchronization, cleanup of unused objects, table replacement — with an unconditional backup and `$ScriptVersion` | "Scripts" |
| 7 | **DAX queries against the open model** | Testing hypotheses on the data (duplicates, totals, reconciliation with SAP), not only on the formulas in TMDL | "Querying the open Power BI Desktop model" |
| 8 | **Editing the model "on the fly" via TOM** | Desktop is open — changes go into the model via TOM, visuals are fixed in the folder | "Editing the open model "on the fly" (TOM)" |
| 9 | **Tabular Editor macro → script over TMDL** | The "Add Display Folder" macro (`%LOCALAPPDATA%\TabularEditor\MacroActions.json`) was ported to `RenameObjects.ps1` Part 4 — applied without Tabular Editor | "`RenameObjects.ps1`" → Part 4 |
| 10 | **DAX performance** | Measuring in DAX Studio (Server Timings, Clear Cache then Run) | `ClientA_Context.md` |
| 11 | **Power BI Service automation** | Publishing a `.pbix` to several workspaces; emailing PDFs per employee without Premium — browser (Playwright) + Microsoft Graph | "`PublishPowerBIApp.ps1`", "Emailing the report as PDF without Premium — ReportMailer" |
| 12 | **Infrastructure** | Gateway (check, finding clones, enable/disable, reinstall), updating Gateway/Desktop/SSMS, the Power Loader scheduled task | "Gateway and Desktop/SSMS updates — `Gateway Scripts`", "Power Loader" |
| 13 | **Maps** | Concave hull of points → GeoJSON/WKT polygon for map visuals | "Maps: polygons from points (`TeamBI`)" |
| 14 | **Style rules as text for the AI** | The user writes down their style in files; the AI checks against them before editing | [BPARules_ClientA.json](<../Rules/BPARules_ClientA.json>) (DAX/model, until 2026-10-12 — `Best Practice.txt`), [SQL Formatting Rules.md](<../Rules/SQL Formatting Rules.md>), [Power Query Formatting Rules.md](<../Rules/Power Query Formatting Rules.md>); report design per the IBCS standard — [IBCS_Rules_EN.md](<../Rules/IBCS_Rules_EN.md>) (summary of [IBCS_v1-2.pdf](<../../IBCS_v1-2.pdf>)); `ClientA\CLAUDE.md` |
| 15 | **Per-project context files** | Business logic kept separate from the PBIP structure: `<Project>_Context.md` — business/SQL, this file — PBIP/tools | [ClientA_Context.md](../Clients/ClientA_Context.md), [Collateral_Context.md](../Clients/Collateral_Context.md), [Agency_Context.md](../Clients/Agency_Context.md), [ClientG_Context.md](../Clients/ClientG_Context.md), [ATID_Ageing_UnassignedReceipts_Decisions.md](../Clients/ATID_Ageing_UnassignedReceipts_Decisions.md) |
| 16 | **List of Power BI pain points for Microsoft** | Limitations found are collected for feedback | [MS_Questions.md](../Other/MS_Questions.md) |
| 17 | **MCP servers and CLIs for the AI** (2026-10-14) | MS Power BI Modeling MCP (model, `--readonly`), Desktop Bridge CLI (reload/status/screenshots), TE2 CLI (BPA), `pbir` (PBIR report); overview of SemanticOps and others | [AI_Tools_MCP_CLI.md](../Tools/AI_Tools_MCP_CLI.md) |

### AI working rules (developed in practice)

- **Backup to `ClientA\BackUp\` before any file edit.** The project is not under
  git. Incident 2026-09-13: a script deleted 475 measures without a backup, 30 of them
  were in use. Scripts that change the model back up on their own, unconditionally.
- **Do not change measures without an explicit request.** If an SQL/column edit
  affects measures — list the affected measures, but do not touch them. Offer SQL and measures
  as separate options, not as a bundle.
- **First test on a single visual and check against a reference** (Excel,
  SAP), then — into the theme, calculation group, shared measure.
- **Check on the data, not only on the formulas** — `QueryOpenModel.ps1`.
- **Structural model changes — one at a time, with agreement**, not
  in bulk and not autonomously.
- **Default formats:** new measures — `#,0` or `0.0%`; ID columns
  (`Month ID`, `Month SortBack`…) — `#,0`; lookup tables "name + index" —
  `sortByColumn` on the index right away.
- **Desktop is open → file edits on disk live only until Ctrl+S** (see
  "Editing the open model "on the fly" (TOM)").
- **Page/visual folder names — ASCII only**, otherwise Publish breaks.
- **"Update the calendar" (обнови календарь) = merge, not replace** (user, 2026-10-22): add the work of the
  reference `C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Reference\DAX PRO Solutions\Calendar.json` to the report's current `Calendar` — keep every existing
  column, hierarchy, date range and anything visuals/measures use; diff first, list added / changed / kept.
- **Keep a visual's formatting when you rebuild it** (user, 2026-10-22): new fields or a new
  model structure behind a visual must not silently drop column widths, per-column fills,
  conditional formatting, number formats or header labels — carry them over, diff before/after;
  what cannot be kept — agree with the user first. How — `PBIP_Pages_Visuals.md` →
  "Keeping formatting when a visual's fields change".
- **Scripts are self-contained**: they are often pasted into the console, in which case
  `$PSScriptRoot` is empty and calling a neighboring file fails.
- **Master copy of a script ≠ project copy**: when editing the master, update
  the copies in the projects, compare by `$ScriptVersion`.
- **Page layout and page order** — per the rules of the section "Page
  layout and ordering rules (2026-10-10)"; measure formats — per
  `BPARules_ClientA.json` → rules `PERCENTAGE_FORMATTING`, `INTEGER_FORMATTING`,
  `BP_CHANGE_*`, `BP_FTE_FORMATTING`.

### All saved scripts and templates

**PBIP — report and model** (`ClientA\_Documentation\`; project copies of
`CleanUnused.ps1`/`RenameObjects.ps1` — in `Agency\Budget vs Actual\`):

| File | What it does | What it changes | Section |
|---|---|---|---|
| [RenameObjects.ps1](<../../Scripts/RenameObjects.ps1>) (formerly `rename_pages.ps1`, version `2026-10-15.1`) | Page/visual folder names from `displayName`/title (ASCII only), fixing navigation/drillthrough/group references, `FitToPage` + vertical centering (pages + theme `page.*` default since `2026-10-15.1`), rounding coordinates; optionally measure Display Folders | `.Report`; `.SemanticModel` — only with `-SetMeasureDisplayFolders` (with backup) | "`RenameObjects.ps1`" |
| [CleanUnused.ps1](<../../Scripts/CleanUnused.ps1>) (formerly `Find-UnusedMeasures.ps1`, version `2026-10-17.2`) | Finds and deletes unused measures, measures with a reference to a non-existent table, Field Parameters, tables and calculation groups; unused filter cards (visual + page level, Step 9); `-Port` — Desktop open: the same deletions in the open model via TOM + save | `.SemanticModel` (+ `.Report`), backup to `ClientA\BackUp\` | "`CleanUnused.ps1`" |
| [FormatPowerQuery.ps1](<../Rules/FormatPowerQuery.ps1>) | M step names (`#"Added Custom"` → `AddColumn`), removing empty steps, merging `AddColumn` + typing | `.pq` files in place, **no backup** | "`FormatPowerQuery.ps1`" |
| [Scripts/ReplaceModelTable.ps1](<../../Scripts/ReplaceModelTable.ps1>) (version `2026-10-16.3`) | Replaces a model table with another one everywhere: Desktop closed — TMDL (relationships, `model.tmdl`, translations) + report; `-Port` — live swap in the open Desktop via TOM (relationships re-created, old table deleted, `-KeepName`, `-DropFilters`), report via `ReportFields.py`; `-ReportOnly` | `.SemanticModel` + `.Report` (or the open model), backup | "`ReplaceModelTable.ps1`" |
| [Scripts/fix_nonascii_names.ps1](<../../Scripts/fix_nonascii_names.ps1>) | One-off: non-ASCII folder names → hex ID | `.Report` | "`fix_nonascii_names.ps1`" |
| [Scripts/Rename-ReportTheme.ps1](<../../Scripts/Rename-ReportTheme.ps1>) | Attaches a new theme file and switches the three references in `report.json` | `.Report`, backup | "`Rename-ReportTheme.ps1`" |
| [Scripts/QueryOpenModel.ps1](<../../Scripts/QueryOpenModel.ps1>) | DAX `EVALUATE` query against the model open in Desktop | nothing (read-only) | "Querying the open Power BI Desktop model…" |
| [Scripts/OcrImage.ps1](<../../Scripts/OcrImage.ps1>) | Windows OCR of a screenshot → `X\|Y\|text` lines (checking titles/labels without viewing the image) | nothing (read-only) | `AI_Tools_MCP_CLI.md` → "Reading screenshots" |
| [Scripts/CompareScreens.py](<../../Scripts/CompareScreens.py>) | Before/after screenshots → changed regions, OCR text diff, changed-pixel colors, crops; `--expect` warns about side effects | nothing (writes crops to a temp folder) | `AI_Tools_MCP_CLI.md` → "Verifying an edit" |
| [Scripts/ReportFields.py](<../../Scripts/ReportFields.py>) (version `2026-10-16.1`) | Report fields and filters, sub-commands: `replace` (a column / level / whole table / rename everywhere in the report), `drop-filters` (every filter on a column + Markdown list), `clean-filters` (empty unused Filters-pane cards), `refs` (references per column); dry run by default | `.Report`, backup, `pbir validate` before/after | `PBIP_Scripts.md` → "`ReportFields.py`" |
| [Scripts/CopyVisualSetup.py](<../../Scripts/CopyVisualSetup.py>) (version `2026-10-15.1`) | Copies fields, visual-level measure filters, size and x of a template visual to other visuals | `.Report`, backup | `PBIP_Scripts.md` → "`CopyVisualSetup.py`" |
| [Scripts/CopyDiagramLayout.py](<../../Scripts/CopyDiagramLayout.py>) (version `2026-10-15.1`) | Copies the Model view layout (table positions/sizes) from another model, e.g. an archive copy; matches renamed tables by lineageTag; dry run by default | `.SemanticModel\diagramLayout.json`, backup | `PBIP_Scripts.md` → "`CopyDiagramLayout.py`" |
| [Scripts/MergeSemanticModel.py](<../../Scripts/MergeSemanticModel.py>) (version `2026-10-20.1`) | Two models (e.g. dev copy → main): `compare` object by object (measures, columns, partitions, calc items, relationships, report visuals that would break, rename candidates), `merge` the source's changed / new tables + relationships into the target (`--exclude` junk, `--keep` target objects still in use), `rename-measures` in a report; dry run by default | `.SemanticModel` / `.Report`, backup | `PBIP_Scripts.md` → "`MergeSemanticModel.py`" |
| [Scripts/ValidateTmdl.ps1](<../../Scripts/ValidateTmdl.ps1>) (version `2026-10-20.1`) | Offline: does a TMDL folder load (TOM loader)? Counts or the error with file / line; zero-width Calendar levels patched in a scratch copy | nothing (read-only) | `PBIP_Scripts.md` → "`ValidateTmdl.ps1`" |
| [Scripts/CheckReportRefs.py](<../../Scripts/CheckReportRefs.py>) (version `2026-10-20.1`) | Report fields missing in the model; `--before <backup>` marks NEW vs old | nothing (read-only) | `PBIP_Scripts.md` → "`CheckReportRefs.py`" |
| [Scripts/CaptureDesktopWindow.ps1](<../../Scripts/CaptureDesktopWindow.ps1>) (version `2026-10-20.1`) | PNG of the whole Desktop window + its dialogs by name (the bridge screenshot shows only the canvas) | nothing (writes a PNG) | `PBIP_Scripts.md` → "`CaptureDesktopWindow.ps1`" |
| [Scripts/UpdateSchemas.ps1](<../../Scripts/UpdateSchemas.ps1>) (version `2026-10-15.2`) | Daily (task `UpdatePowerBISchemas`, 09:00): checks the schema copies in `Context` and pbir's bundled schemas against GitHub, installs newer versions, `pbir schema regenerate`; logs a newer pbir release | `Context\*.json` + links in `Context\*.md`; pbir's schema folder; log `Context\PBIP\Schemas\SchemaUpdates.log` | `AI_Tools_MCP_CLI.md` → "Updating pbir's schemas" |
| TOM snippet (no file) | Renaming columns/editing measures in the open model | the open model | "Editing the open model "on the fly" (TOM)" |

**Power BI Service:**

| File | What it does | Section |
|---|---|---|
| [Scripts/PublishPowerBIApp.ps1](<../../Scripts/PublishPowerBIApp.ps1>) | Publishes a `.pbix` to one or several workspaces (overwrite) | "`PublishPowerBIApp.ps1`" |
| [ReportMailer/README.md](<../../ReportMailer/README.md>), [login_setup.py](<../../ReportMailer/login_setup.py>), [export_and_email.py](<../../ReportMailer/export_and_email.py>) | Report PDF per employee (filtered by slicer) → email via Graph, without Premium | "Emailing the report as PDF without Premium — ReportMailer" |

**Infrastructure** (`Agency\`):

| File | What it does | Section |
|---|---|---|
| [CheckGateway.ps1](<../../../../Agency/Gateway Scripts/CheckGateway.ps1>) | Gateway: local service + status in Power BI Service (read-only) | "Gateway and Desktop/SSMS updates" |
| [ScanGateway.ps1](<../../../../Agency/Gateway Scripts/ScanGateway.ps1>) | Scans the subnet, finds machines with a gateway (clones), CSV | same |
| [SetGatewayService.ps1](<../../../../Agency/Gateway Scripts/SetGatewayService.ps1>) | Gateway service: `-Action Stop / Start / Enable / DisableProd / DisableClone` (version guard prod vs clone) | same |
| [ReinstallGateway.ps1](<../../../../Agency/Gateway Scripts/ReinstallGateway.ps1>) | Clean reinstall of the gateway for a new registration | same |
| [UpdateGatewayPowerBIDesktopSSMS.ps1](<../../../../Agency/Gateway Scripts/UpdateGatewayPowerBIDesktopSSMS.ps1>) | Update Gateway / Power BI Desktop (standalone only, not Store) / SSMS in one run (`-Yes` = unattended) | same |
| [SetupUpdateTask.ps1](<../../../../Agency/Gateway Scripts/SetupUpdateTask.ps1>) | Weekly task (Fri 20:00, SYSTEM) running the update with `-Yes` | same |
| [UninstallPowerBIDesktop.ps1](<../../../../Agency/Gateway Scripts/UninstallPowerBIDesktop.ps1>) | Uninstall selected Power BI Desktop versions (standalone and Store) from a list | same |
| [InstallOutlook.ps1](<../../../../Agency/Gateway Scripts/InstallOutlook.ps1>) | Not Power BI: Outlook for all users of the server (located alongside) | same |
| [SetupPowerLoaderTask.ps1](<../../../../Agency/Power Loader/PowerLoader Scripts/SetupPowerLoaderTask.ps1>), [CheckPowerLoaderTask.ps1](<../../../../Agency/Power Loader/PowerLoader Scripts/CheckPowerLoaderTask.ps1>), [RunPowerLoaderTask.ps1](<../../../../Agency/Power Loader/PowerLoader Scripts/RunPowerLoaderTask.ps1>), [DeletePowerLoaderTask.ps1](<../../../../Agency/Power Loader/PowerLoader Scripts/DeletePowerLoaderTask.ps1>), [CheckPowerLoaderTables.sql](<../../../../Agency/Power Loader/PowerLoader Scripts/CheckPowerLoaderTables.sql>) | Scheduled task `PowerLoaderBI`: create, check, run, delete the old one; table freshness | "Power Loader" |

**Maps** (`TeamBI\`): [concave_geojson.py](<../../../../TeamBI/concave_geojson.py>),
[concave_wkt.py](<../../../../TeamBI/concave_wkt.py>),
[sql_to_geojson.py](<../../../../TeamBI/sql_to_geojson.py>) — see "Maps:
polygons from points (`TeamBI`)".

**Templates:** [Calendar.json](<../../Reference/DAX PRO Solutions/Calendar.json>) (calendar table),
[ThemeWarm.json](<file:///C:/Users/ayrat/OneDrive/Документы/ClientA/_Documentation/Reference/Maket/ThemeWarm.json>) (theme) — see "Templates".

**Deleted:** `normalize_visuals.ps1` is described below as history; the file no longer exists.

⚠️ **Before sharing the folder:** `ReportMailer\storage_state.json` —
a saved Power BI sign-in session (whoever gets the file will sign in as that
account), `ReportMailer\downloads\` — PDFs with employee data,
`ReportMailer\config.json` — for the Graph app secret (as of 2026-10-07
it contains placeholders). Share only `README.md` and the `.py` files.


## 🗺️ Section map (file split 2026-10-12)

Previously everything was in this file (3,223 lines). Sections were moved without changes to the text;
references of the form "section title" in the text — look them up in this map. New material —
add it to the file by topic; here — only a line in the map.

**[PBIP_Pages_Visuals.md](PBIP_Pages_Visuals.md)** — PBIP structure, name synchronization, `page.json`/`visual.json`, references, groups, bookmarks, ASCII, cache, common problems

- Core structure of a PBIP project
- Three critical places to keep in sync
  - 1️⃣ Folder name (⚠️ NO SPACES)
  - 2️⃣ Reference in pages.json
  - 3️⃣ The "name" field in page.json (⚠️ NO SPACES)
- ⚠️ CRITICAL RULES
  - Rule 1: Name synchronization (no spaces)
  - Rule 2: displayName — the only place with spaces
  - Rule 3: UTF-8 without BOM
  - Rule 4: JSON formatting — 2 spaces per level
  - Rule 5: Folder name/`name` — ASCII only (not just "no spaces")
- How to rename pages correctly (displayName)
  - The only safe way
  - Handling name collisions
- `page.json` schema (`page-2.1.0.json`)
  - Top-level `page.json` fields — full list per the schema
  - `objects` (`PageFormattingObjects`) — full list of page formatting categories
- Visual structure (visuals/)
  - Key fields of visual.json
  - `$schema` version of the visual is higher than the publicly released one
  - ⚠️ Keeping formatting when a visual's fields change (2026-10-22)
  - ⚠️ Visuals can reference each other by folder ID
  - ⚠️⚠️ Three fields reference a PAGE by its folder name — and this was historically never tracked
  - ⚠️⚠️ `parentGroupName` — visual grouping references by folder ID, and old script versions could silently corrupt it
  - ⚠️ On/Off tab buttons — "On" is not junk, even if hidden and it "does nothing" (ClientB, 2026-10-13)
  - ⚠️ Bookmarks and group visibility — z-order is scoped WITHIN the parent group, not across the whole page
  - ⚠️⚠️ Official MS documentation: renaming risks and auto-removal of invalid references from bookmarks
  - ⚠️⚠️ Non-ASCII folder name of a page/visual breaks Publish/template export
  - Numeric serialization in PowerShell (rounding gotcha)
- ⚠️⚠️ Orphaned page folders (without `page.json`)
- ⚠️ Visual duplication during parallel work
- Power BI Desktop caching
- Common problems and solutions
- displayName vs name structure
- Correctness check
- What Power BI does NOT do
- Conclusion

**[PBIP_Theme.md](PBIP_Theme.md)** — report theme, Style Presets, `visualStyles`, colors

- Report theme and Style Presets
  - Where the theme lives
  - ⚠️ Three places in `report.json` reference the theme file by name — same as with pages/visuals
  - Theme structure: three color levels
  - `colorOrThemeColor` vs `ThemeDataColor` — two different ways to reference a color
  - `visualStyles` and Style Presets
  - UI names vs JSON keys
  - States (`default`/`hover`/`selected`) inside a preset
  - What happens when you click "Style preset" in the Format pane
  - ⚠️⚠️ Inheritance inside `visualStyles` — by the WHOLE array, not by `$id`
  - Style level hierarchy and precedence rule
  - ⚠️ Promoting settings from the "named preset" level to the "visual type (`*`)" level
  - ⚠️⚠️ Key card property: `objects.padding` (`paddingUniform: 0`, `paddingIndividual: false`)
  - ⚠️ Power BI Desktop can silently rewrite `visual.json` while the project is open
  - ⚠️ A theme fundamentally cannot reference measures (DAX)
  - ⚠️ Key collision between the "object" and "container" levels inside a preset
  - ⚠️ `layout.alignment` in the theme accepts only `left`/`center`/`right` (not `middle`)
  - Targeted property override within a single preset, without touching the shared level
  - `GreyShadeTabActive` / `GreyShadeTabInactive` — tab presets (Collector Assignment, 2026-10-16)
  - How to tell what can safely be moved from a visual to a preset
  - ⚠️ Step 2 must not be done "by eye" on a single visual — check against all "siblings" of the same type
  - ⚠️ `tableEx` and `pivotTable` — different sets of allowed keys in `visualStyles`, not interchangeable
  - Table `fill` properties (`backColor`, `gridHorizontalColor`, `outlineColor`, `fontColor`) support `ThemeDataColor`
  - Safely trimming `dataColors`

**[PBIP_Recipes.md](PBIP_Recipes.md)** — visual recipes, page layout and order, templates, KPI card, Copy Navigation

- Visual recipes
  - Padding 0 + title indent with the `⠀` character (U+2800) (2026-10-08)
  - "i" icons above table column headers (2026-10-08)
  - Combo chart: column color — three gotchas (2026-10-08)
  - Recipe: highlight the current (partial) month with an outlined column
  - "i" icons above `SalesSummary` columns (page `PTP`, 2026-10-09)
  - Visual name in the Selection pane (layers)
  - Visual header icons (`visualHeader`) — full list of properties
- Page layout and ordering rules (2026-10-10)
  - Grid (background `Background*.svg`, 1920×1080)
  - Page order and visibility
  - Example: `Collector Assignment` + `Collateral` pages (2026-10-10)
- Tab-navigation pages `Tabs *` (Collector Assignment, 2026-10-16)
- Recipe: drill from a matrix cell to the rows behind it (metric axis, 2026-10-22) — why not a field parameter, `MAX` vs `SELECTEDVALUE`, variant E (field parameter on the detail page, in production), benchmark
- Recipe: answer client call requests with a test version (2026-10-23) — call summary → data check → named test copy → Desktop verification → review table
- Recipe: a new thin report on a live connection, built from files (Risk, 2026-11-02) — model first (columns / measures / colors, user publishes), scaffold, generated pages (tabs, synced slicers, twin-page toggle, explicit series colors), offline checks
- Templates
- Recipe: swap a legacy date table for the central `Calendar` (ClientB, 2026-10-18)
- Recipe: add a new KPI card (cardVisual + time-intelligence measures)
  - Measures (in `Measure.tmdl`)
  - Card (`visual.json`)
  - Positioning
- Recipe: [Copy Navigation Buttons] (alias [Copy Navigation])
  - Steps
  - Technical notes

**[PBIP_Scripts.md](PBIP_Scripts.md)** — PowerShell scripts (RenameObjects, CleanUnused, ReplaceModelTable, FormatPowerQuery, Publish…)

- Scripts
  - Script versioning (`$ScriptVersion`)
  - `RenameObjects.ps1` (formerly `rename_pages.ps1`)
  - `fix_nonascii_names.ps1`
  - `normalize_visuals.ps1` — removed (functionality spread across other scripts)
  - `Rename-ReportTheme.ps1` (added 2026-09-19)
  - Real-world example: the `Warm` preset (`Collector Assignment`, 2026-09-19)
  - `ReplaceModelTable.ps1` (formerly `Replace-ModelTable.ps1`)
  - `ReportFields.py` — report fields and filters
  - `CleanUnused.ps1` (formerly `Find-UnusedMeasures.ps1`)
  - `FormatPowerQuery.ps1`
  - `PublishPowerBIApp.ps1`
  - How to run (double-click does not work!)

**[PBIP_Model_Live.md](PBIP_Model_Live.md)** — DAX queries against the open model, edits via TOM, DAX UDF

- Querying the open Power BI Desktop model — `QueryOpenModel.ps1` (added 2026-10-04)
  - How it works
  - Script
  - Limitations and gotchas
  - Useful DAX techniques for diagnostics
  - Real-world example: ClientE `Sales Main` (2026-10-04)
- Editing the open model "on the fly" (TOM) — rule since 2026-10-06
  - How it works
  - Order and gotchas
  - Checking the model for errors after edits (2026-10-13)
  - Fixing a visual after renaming — directly in the folder (decision 2026-10-06)
  - Example: Collateral, 2026-10-06
- Invisible hierarchy level names — use quoted NBSP, not zero-width spaces (2026-10-14)
- DAX User-Defined Functions (`functions.tmdl`)
  - Syntax
  - Parameter types
  - `Collection.FormatRefLabel` — formatting the prior-period comparison string
  - `///` doc-comment — the function's "Description" field (TOM), not `description:`
  - ⚠️ 2026-09-15 — 100%/-100% formatting fix + doc-comment + inline comments
  - Working with `functions.tmdl`/`Measure.tmdl` — the same CRLF gotcha as everywhere in TMDL

**[AI_Tools_MCP_CLI.md](../Tools/AI_Tools_MCP_CLI.md)** — MCP servers and CLIs for the AI (added 2026-10-14)

- ✅ Decision 2026-10-14: which tool for which task (approved by the user)
- Summary: what we replace with what
  - Verified rename workflow (2026-10-14)
  - Market research summary (2026-10-14)
- Token cost per tool call (measured 2026-10-14, keep updating)
- Installed (2026-10-14): MS Power BI Modeling MCP, Desktop Bridge CLI, Tabular Editor 2 CLI, pbir-cli
  - Write mode test; Full test run (2026-10-14) — COMPLETED
  - Reading screenshots: OCR for text, DAX for numbers, image for layout
  - Verifying an edit: `CompareScreens.py` (before vs after)
- Not installed — for reference

**[Infrastructure.md](../Tools/Infrastructure.md)** — Power Loader, ReportMailer, gateway, maps

- Power Loader: scheduled task `PowerLoaderBI` (added 2026-10-04)
  - Schedule
  - ⚠️ The task on the server ≠ `SetupPowerLoaderTask.ps1` (found 2026-10-07)
  - ⚠️ Duplicated code
- Emailing the report as PDF without Premium — ReportMailer (since 2026-09-15)
- Gateway and Desktop/SSMS updates — `Gateway Scripts` (2026-09-30 … 2026-10-07)
  - Power BI Desktop on this workstation (2026-10-14) — two installs, Bridge needs 2.158+, legacy theme, settings differences
- Maps: polygons from points (`TeamBI`)

**[ClientA_Context.md](../Clients/ClientA_Context.md)** → "PTP report pages — formatting": pages `PTP Resolved reconciliation`, `PTP Bridge`.
