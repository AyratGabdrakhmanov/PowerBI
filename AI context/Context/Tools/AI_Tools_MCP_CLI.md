# AI tools for Power BI: MCP servers and CLIs (2026-10-14)

> Part of the PBIP knowledge base. Table of contents — [POWERBI_PBIP_STRUCTURE.md](../PBIP/POWERBI_PBIP_STRUCTURE.md).
> Our "manual" approach (ADOMD queries, TOM, file edits) — [PBIP_Model_Live.md](../PBIP/PBIP_Model_Live.md).

Market overview done 2026-10-14 from README/Microsoft Learn (links below);
installed and verified on this machine — see the "Installed" section.

> **Split into the folder `AI_Tools_MCP_CLI\` on 2026-11-06** — this file is the index, the content is in the files below (moved verbatim; an old reference "AI_Tools_MCP_CLI.md → <section>" finds the section by its title here). New content goes into the section file, a new section = a new file + a line here. Convention: `README.md` of this folder's parent.

## ✅ Decision 2026-10-14: which tool for which task (approved by the user)

Standing workflow after the end-to-end tests; token cost per use in brackets.

| # | Task | Use | Fallback |
|---|---|---|---|
| 1 | DAX query / check numbers | MS MCP `dax_query Execute` — `resultMode: Inline`, `maxRows`, no metrics (~150–300) | `QueryOpenModel.ps1` (~50) |
| 2 | Model error scan after edits | MS MCP: `INFO.MEASURES/COLUMNS/RELATIONSHIPS()` with `[State] <> 1` | same query via `QueryOpenModel.ps1` |
| 3 | Model edits, Desktop open | MS MCP operations (rollback; rename fixes dependent DAX); `Validate` before writing DAX (~100–300 per call) | TOM PowerShell (`PBIP_Model_Live.md`) |
| 4 | Model edits, Desktop closed | text TMDL edits for small changes; TE2 `-S script.csx -TMDL` for bulk | MS MCP `ConnectFolder` — after the model's Calendar levels are converted to quoted NBSP (`PBIP_Model_Live.md`, "Invisible hierarchy level names") |
| 5 | Visual formatting | `pbir schema describe` → `pbir get/set` on one property (~50–500 instead of reading `visual.json`, 3–10k) | manual `visual.json` edit |
| 6 | Field rename in the report | `pbir fields replace` + grep leftovers + regex for them | regex only |
| 7 | Load disk edits into Desktop | Bridge `status` → `reload` (real file: ask the user first) | user clicks Apply external changes |
| 8 | Verify an edit visually | Bridge `screenshot` before/after → `CompareScreens.py --expect` (~100) → view only `region_N.png` (~70) | full screenshot (~1.7k) |
| 9 | BPA | TE2 CLI `-A BPARules_ClientA.json`, grouped by rule (~1k) | Tabular Editor GUI |
| 10 | Report file check | our field-reference check (`CleanUnused.ps1` Step 10) + `pbir validate` **counts only** | — |
| 11 | Quick performance check | MS MCP `Execute` + `getExecutionMetrics` (~800) | DAX Studio for deep analysis |
| 12 | Bulk clean-up / renames | **keep** `CleanUnused.ps1`, `RenameObjects.ps1`, `ReplaceModelTable.ps1` | — |

Token rules: never read raw dumps (group TE2 output, filter Bridge `status`, CompareScreens
`--max-regions`); `pbir get` a single property, not whole objects; no MCP `GetStats`
(~2k) — query `INFO.TABLES()` columns you need.

## Summary: what we replace with what

| Our task | Before (our approach) | After (tool) |
|---|---|---|
| DAX query against the open model | `QueryOpenModel.ps1` (ADOMD, port from `msmdsrv.port.txt`) | MS Power BI Modeling MCP → `dax_query` (connection **by file name**, no port guessing). The script remains as a fallback |
| Editing the open model | TOM from PowerShell, no rollback | MS MCP (read-write since 2026-10-14): transactions with **rollback**; a rename **rewrites dependent DAX itself**; `dax_query Validate` before writing |
| Editing TMDL with Desktop closed | text edits to files | MS MCP `ConnectFolder` — ⚠️ fails on our zero-width Calendar levels; until they are renamed — **TE2 C# script** `-S … -TMDL` (loads them fine) |
| "Apply external changes" after file edits | the user clicks it manually | Desktop Bridge CLI `powerbi-desktop reload` (~6 s) |
| Did Ctrl+S overwrite our edits (the 2026-10-09 case) | we ask the user | `powerbi-desktop status` → `hasUnsavedChanges` (Desktop sets it by itself after load — ask before `reload` on a real file) |
| See what a visual looks like | the user sends a screenshot | `powerbi-desktop screenshot <pageId>` / `screenshot-all`; compare with `CompareScreens.py` |
| Renaming a field in `visual.json` | regex `(?<=[".])Name(?=")` | `pbir fields replace --from T.Old --to T.New` **+ grep for leftovers** (it missed a slicer's saved selection) — the regex stays for those |
| Report check | our own script reconciling `SourceRef` with TMDL | `pbir validate` — compare the error count with the original (our reports: 217 schema false positives); visual check — `CompareScreens.py --expect` |
| BPA against `BPARules_ClientA.json` | manually in the Tabular Editor GUI | TE2 CLI `TabularEditor.exe <model> -A <rules>` — group the output by rule (raw ~60k tokens) |

None of the model tools (MS MCP, SemanticOps, TE) **edits the report** —
the "renaming breaks visuals" gotcha (see `PBIP_Model_Live.md`, item 7)
remains; the report layer — only `pbir` / file edits. A broken field does not always
show an error: a slicer that loses its field simply stops filtering and the numbers
change silently (seen 2026-10-14) — always compare before/after.

**Verified rename workflow (2026-10-14):** MCP `column_operations Rename` → check
dependent measures (`INFO.MEASURES()` state + values) → user **Ctrl+S** → `pbir backup`
→ `pbir fields replace` → grep leftovers, fix by regex → `pbir validate` (same error
count as before) → `powerbi-desktop reload` → `screenshot` → `CompareScreens.py`
against the "before" screenshots (identical = done).

### Market research summary (2026-10-14)

- **Microsoft:** the "Power BI Modeling MCP" is now documented as the **Power BI
  Authoring MCP** — local server (GA, installed here) + hosted preview
  (`api.fabric.microsoft.com/v1/mcp/powerbi/authoring`, Fabric models only). The old
  natural-language **Consumption MCP** is being replaced by **Fabric IQ MCP** (read-only
  DAX/metadata on published models, RLS enforced). Report layer: the
  `skills-for-fabric` `powerbi-authoring` plugin (PBIR skills + MCP + Bridge, preview).
  Fabric CLI `fab` — export/import/deploy whole definitions, no DAX.
- **Maxim Anatsko:** **SemanticOps MCP** (closed source, live model only — no PBIP
  files, no report layer; rollback/tests/policies in Pro $349/yr) and **pbir-cli**
  (with Kurt Buhler; report layer; custom non-commercial licence — use confirmed by
  the user 2026-10-14). He has no model CLI ("pbi-cli" is MinaSaad1's).
- **Others, strongest:** data-goblin `power-bi-agentic-development` (Claude Code
  plugins over `te`/`fab`/`pbir`), Tabular Editor 3 MCP (paid), Tabular Editor `te`
  CLI (preview), MinaSaad1 `pbi-cli`, sulaiman013 `powerbi-mcp` — see "Not installed".

## Token cost per tool call (measured 2026-10-14, keep updating)

Rough cost of the output the AI has to read (≈ characters / 4). Rule: read
summaries, never raw dumps; filter before reading.

| Call | Cost | Cheaper way |
|---|---|---|
| TE2 BPA raw output (Collector Assignment: 1,520 lines) | **~60k — never read raw** | group by rule in PowerShell → ~1k |
| MCP `model_operations GetStats` (39 tables) | ~2k | `dax_query` on `INFO.TABLES()` with only the needed columns |
| MCP `measure_operations Get` (2 measures) | ~600 (much metadata per measure) | `INFO.MEASURES()` filtered to `Name`/`Expression` |
| MCP `dax_query Execute` + `getExecutionMetrics` | ~800 | without metrics ~150–300; metrics only for performance work |
| `QueryOpenModel.ps1` (1-row result) | ~50 | — (cheapest; but 2.9 s and needs the port) |
| `powerbi-desktop status` (report with many pages) | ~1.5k (every page with full path) | pipe through `Select-String 'currentFilePath\|hasUnsavedChanges'` → ~100 |
| `pbir ls` page (24 visuals) | ~800 | `pbir find` / a glob for the one visual |
| `pbir get …title` (whole object) | ~500 | `…title.text` → a few tokens |
| Viewing a full-page screenshot | ~1.7k | `CompareScreens.py` region crop ~70; OCR text ~1k |
| `CompareScreens.py` report | ~100 | — |

## Sections

- [Installed (2026-10-14)](AI_Tools_MCP_CLI/01_Installed_2026_10_14.md) — 2 lines
  - [1. Microsoft Power BI Modeling (Authoring) MCP — the model](AI_Tools_MCP_CLI/02_1_Microsoft_Power_BI_Modeling_Authoring_MCP_the.md) — 229 lines
  - [2. Power BI Desktop Bridge CLI — controlling the open Desktop](AI_Tools_MCP_CLI/03_2_Power_BI_Desktop_Bridge_CLI_controlling_the_op.md) — 170 lines
  - [3. Tabular Editor 2 CLI — BPA from the command line](AI_Tools_MCP_CLI/04_3_Tabular_Editor_2_CLI_BPA_from_the_command_line.md) — 19 lines
  - [4. pbir-cli — the report layer (PBIR)](AI_Tools_MCP_CLI/05_4_pbir_cli_the_report_layer_PBIR.md) — 62 lines
  - [5. GitHub CLI (`gh`) — authenticated GitHub API (installed 2026-10-15)](AI_Tools_MCP_CLI/06_5_GitHub_CLI_gh_authenticated_GitHub_API_install.md) — 10 lines
  - [6. pbixray — read a .pbix model offline (installed 2026-10-20)](AI_Tools_MCP_CLI/07_6_pbixray_read_a_pbix_model_offline_installed_20.md) — 31 lines
  - [7. DAX Studio CLI (`dscmd`) — query benchmark (DAX Studio 3.6.1, used 2026-10-22)](AI_Tools_MCP_CLI/08_7_DAX_Studio_CLI_dscmd_query_benchmark_DAX_Studi.md) — 27 lines
  - [8. SQL MCP `sql-mcp` — DBHub, read-only SQL to ClientA ClientA-DB (set up 2026-11-06)](AI_Tools_MCP_CLI/09_8_SQL_MCP_sql_mcp_DBHub_read_only_SQL_to_ClientA_Aut.md) — 26 lines
  - [9. DAX Lib MCP (`daxlib`) — daxlib.org UDF packages (installed 2026-11-07)](AI_Tools_MCP_CLI/12_9_DAX_Lib_MCP_daxlib_UDF_packages.md) — 18 lines
- [Client Word documents (docx-js, Hebrew RTL)](AI_Tools_MCP_CLI/10_Client_Word_documents_docx_js_Hebrew_RTL.md) — 12 lines
- [Not installed — for reference](AI_Tools_MCP_CLI/11_Not_installed_for_reference.md) — 14 lines
