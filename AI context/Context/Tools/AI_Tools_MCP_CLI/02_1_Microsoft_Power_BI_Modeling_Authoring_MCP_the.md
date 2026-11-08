Part of [AI_Tools_MCP_CLI.md](../AI_Tools_MCP_CLI.md) (split 2026-11-06).

## 1. Microsoft Power BI Modeling (Authoring) MCP — the model

- Repo: <https://github.com/microsoft/powerbi-modeling-mcp>; documentation:
  <https://learn.microsoft.com/en-us/power-bi/developer/mcp/power-bi-authoring-mcp>.
  Version **1.0.0** (GA, npm 2026-09-25). Free, MIT + EULA.
- Connected in user-level `~/.claude.json` → `mcpServers.powerbi-modeling`:
  `cmd /c npx -y @microsoft/powerbi-modeling-mcp@1.0.0 --start --readonly --accepteula`
  (config backup — `ClientA\BackUp\claude.json_20261014_082144.bak`).
  Picked up only at session start (Reload Window). Tools —
  `mcp__powerbi-modeling__*`.
- ⚠️ **EULA:** before the tools are first used, the EULA must be accepted
  (the `accept_eula` tool, the `--accepteula` flag or
  `PBI_MODELING_MCP_ACCEPT_EULA=true`) — the user accepts it personally.
  **Accepted by the user 2026-10-14** → the `--accepteula` flag in `args`.
- **Rule (user, 2026-10-23, final): Claude saves Desktop itself with Ctrl+S** (`Save-Desktop` below: window
  brought forward, foreground pid checked = the target, only then SendKeys), confirmed by file timestamps;
  **never a UI Automation click on the Save button.** ⚠️ After an MCP calculated-table create + `Calculate`
  refresh the save can take longer than 120 s (2026-10-24: the files were written ~150 s after Ctrl+S, the
  check had already reported "nothing written") — before asking, look at the window title ("Last saved: …",
  `CaptureDesktopWindow.ps1`) and the TMDL timestamps again. If Ctrl+S does not reach the files in 120 s, ask the
  user to save. (Earlier that day self-saving was forbidden for a few hours, then allowed again.)
- **Saving without the user:** no tool saves Desktop — the Bridge (1.0.0 manifest:
  `application.state.get`, `report.snapshot.capture` v1/v2, `file.reload`), the MS
  Modeling MCP (`ExportToTmdlFolder` writes model files only: the report is not saved,
  `hasUnsavedChanges` stays, the next Ctrl+S overwrites) and `pbir` (files only).
  Bring the window forward and send Ctrl+S, then poll `powerbi-desktop status --pid
  <pid>` until `hasUnsavedChanges: false`. ⚠️ **`AppActivate(<pid>)` alone is not safe**
  (ClientB 2026-10-16): with two "Sales_ClientB - Power BI Desktop" windows open it left another
  window in front and Ctrl+S went elsewhere (the target was not saved). Use `Save-Desktop` from
  `ReplaceModelTable.ps1`: `ShowWindow` + an Alt key press + `SetForegroundWindow`, then check
  `GetForegroundWindow` → `GetWindowThreadProcessId` = the pid, and only then
  `SendKeys('^s')`; otherwise stop without sending keys. Confirm by file timestamps. ⚠️ While the user
  works in **Remote Desktop** (`mstsc.exe`) it keeps the foreground — `SaveDesktop.ps1` refuses ("Foreground
  is pid …"); don't retry in a loop, ask the user to Ctrl+S, and no `reload` until then (it would drop the TOM edits).
  ⚠️ Right after a `reload`
  the flag turns `true` by itself and stays `true` even after a real save (ClientB 2026-10-16),
  so there it proves nothing: check the TMDL / JSON timestamps on disk instead. No save is
  needed right after a `reload` anyway — disk and Desktop are the same.
  ⚠️ **Save BEFORE the file edit — afterwards it is too late** (Collector Assignment
  2026-10-16): once Desktop shows the yellow banner "This project's files were changed
  externally", `Save-Desktop` (Ctrl+S, the window was confirmed in front) writes **nothing**
  — no file changes in 120 s, `hasUnsavedChanges` stays `true`, the title keeps "Last saved:
  yesterday". Restoring the original files from the backup did not help either: the banner
  stays and Ctrl+S is still ignored. Then the only options are `reload` (Desktop's unsaved
  edits are lost) or the user saves/decides by hand → with an unknown flag, **ask**.
  Order: `status` → the user saves → confirm by timestamps → edit files → `reload`.
  ⚠️ **The user may be editing in the same Desktop at the same time** (2026-10-24, several times): a Ctrl+S after
  my file edit wrote Desktop's version over my edits (and kept a column bound to a measure I had just deleted);
  a `reload` while the user edits fails ("Host is not ready", banner "files were changed externally") or would
  drop their unsaved work. So: check `hasUnsavedChanges` **right before every file edit**; if `true`, save first
  (keeps the user's work), then edit, then `reload`; after the save, re-read the files I am about to change —
  they may carry the user's edits (keep them). Delete model objects only after the files no longer reference them.
  ⚠️ **Ctrl+S can be ignored with no banner** (Overview Drill copy 2026-10-22, after MCP model
  edits): the window was confirmed in front, nothing was written in 120 s. Fallback that worked:
  UI Automation → the title-bar button `Name = 'Save'` (AutomationId `save`) →
  `InvokePattern.Invoke()` (same code as "Fit to page" below), then confirm by timestamps.
  - Two Desktop windows on the same `.pbip` (2026-10-15, PIDs opened 13:10 and 22:05):
    a save in one window shows "Apply external changes" in the other. Check
    `Get-Process PBIDesktop` titles/StartTime first when the banner appears unexpectedly.
  Closing
  (`(Get-Process -Id <pid>).CloseMainWindow()`) — test copies only, never real files.
- **Mode:** started `--readonly` on 2026-10-14, switched to **read-write** the same day
  for the write tests (`--readonly` removed from `args`). Microsoft's docs promise a
  confirmation before the first write — in Claude Code it never appeared. To go back to
  read-only, add `--readonly` to `args` again and Reload Window.
- Permission rule `mcp__powerbi-modeling__dax_query_operations` in
  `~/.claude/settings.json` (2026-10-14) — otherwise the auto-mode classifier blocks
  DAX queries in read-write mode.
- Connections: Desktop by file name (`ConnectToPowerBIDesktop`), Fabric via
  XMLA (`ConnectToFabric`, requires XMLA Read Write), PBIP/TMDL folder offline
  (`ConnectToPBIP`).
- 21 tools: connection, database (TMDL import/export, deploy),
  transaction, model (refresh, stats), table, column, measure, relationship,
  dax_query (execute/validate), trace, partition, user_hierarchy,
  calculation_group, security_role (RLS), perspective, named_expression,
  function (DAX UDF), culture, object_translation, calendar, query_group.
- **Gotchas (2026-10-28, ClientE):**
  - A new / re-pointed **relationship** answers "…which does not hold any data because it needs to be recalculated"
    until `model_operations RefreshWithXMLA refreshType Calculate` (DAX-only, allowed on client models).
  - **Rebuilding a DATATABLE selector:** `partition_operations Update` (new `DATATABLE`) + `RefreshWithXMLA Calculate` on
    that table → the engine re-infers the columns (old ones dropped, new ones added); then `column_operations Update` for
    format / summarize / sortBy. Measures that pointed at the old columns are in error until rewritten — rewrite them in
    the same session (a TOM script with assert counts is easiest for long expressions).
  - `relationship_operations Create` without `name` → name `<FromTable>_<FromCol>_<ToTable>_<ToCol>` (fine).
  - A Desktop save can move visuals to a newer `visualContainer` schema (2.14.0, 2026-10-28) that `pbir` does not ship →
    more `SCHEMA_DEGRADED` warnings in `pbir validate` without any change of ours; compare counts per visual, not totals.
  - `SaveDesktop.ps1 -Expect` regexes are matched line by line in practice — check a single-line fragment
    (`DIVIDE ( __Result, __Result )`), not text across a line break.
- Limitations: model only (no pages/visuals); DAX result ≤
  100,000 rows; metadata and query results are sent to the LLM provider.
- Verified: the server starts, `Tool Mode: ReadOnly`. 2026-10-14 after
  Reload Window: `connection_operations ListLocalInstances` → sees Desktop
  with the **window name** (`Sales_ClientB`) and port → `Connect` →
  `model_operations GetStats` (34 tables, 138 measures, 24 relationships) and
  `dax_query_operations Execute` (`resultMode: Inline`, 28 ms) — they work.
- ⚠️ 2026-11-02: `ListLocalInstances` returned **0** with Desktop open (same case as `QueryOpenModel.ps1
  -ListInstances`). Way out: port from the newest `msmdsrv.port.txt` (UTF-16) in
  `%LOCALAPPDATA%\Microsoft\Power BI Desktop\AnalysisServicesWorkspaces\*\Data`, confirm the model with a query on an
  object only it has, then `Connect` with `connectionString: "Data Source=localhost:<port>"` — works (measure Create +
  object translations, saved by `SaveDesktop.ps1 -Expect`).
- The same rules as for TOM (`PBIP_Model_Live.md`): backup before editing,
  model edits with Desktop open live until Ctrl+S.

#### ⚠️ Desktop hung after MCP model edits (Collector Assignment, 2026-10-16)

MCP on the open real model: `column Create` (calculated) + `RefreshWithXMLA Calculate` + a failed
`column Update` (sort-by → circular dependency, rolled back) + reconnect + `Calculate` again +
`measure Create` + sort-by. The engine had everything (DAX queries OK), but Desktop showed
"Working on it" for 30+ min (Desktop process ~1 core, `msmdsrv` idle), and Ctrl+S was ignored
(nothing written). Way out: write the same objects into TMDL by hand (definitions with
`lineageTag` from `measure/column ExportTMDL`), kill the Desktop process + its `msmdsrv`
(user's decision), `powerbi-desktop open` — Desktop computes a new calculated column itself on
open, no refresh needed. Also: "The base version must not be negative when impact is requested"
from `RefreshWithXMLA` after a failed transaction = stale connection → `Disconnect` + `Connect`.
**Lesson:** for a calculated column + sort-by in a real model, prefer TMDL files with Desktop
closed (or save + edit TMDL + reopen) over live MCP edits.

**Second case, same day:** hierarchy level rename + new
lineageTags written to `Calendar.tmdl`, then Bridge `reload` — the report part reloaded, the
**model metadata did not** (`INFO.LEVELS()` still showed the old level name) → for model
changes in an open Desktop use TOM/MCP live, not TMDL + `reload`. MCP `RenameLevels` refuses an
NBSP name ("newLevelName is required") → TOM (`$level.Name = [string][char]0xA0`) worked. Desktop
crashed shortly after (Tabular Editor was connected to the same instance at the time; cause not
established).

#### Write mode test (2026-10-14, Collector Assignment test copy)

- Switched to read-write on 2026-10-14 (`--readonly` removed from `args`;
  config backup in `ClientA\BackUp\claude.json_*.bak`). Only ever connect it to a
  test copy while testing — see the "test on copies only" rule.
- **Before any write, prove which file the port belongs to:** two Desktop windows
  can have the same title (real file and its copy). Check
  `powerbi-desktop status` → `currentFilePath` + `pid`, and that the `msmdsrv.exe`
  on the MCP port is a child of that pid
  (`Get-CimInstance Win32_Process -Filter "ProcessId=<msmdsrv pid>"` → `ParentProcessId`).
- `transaction_operations Begin` → `measure_operations Create` → `Rollback` →
  `Get` returns "not found": **rollback works**.
- **No confirmation prompt** appeared before the first write (the docs promise one
  per database; Claude Code did not show it) — do not rely on it as a safety net.
- Inside an open transaction the MCP **defers DAX validation** until commit
  ("Server state … is only computed on transaction commit") — re-read the object's
  `state`/`errorMessage` after committing.
- In read-write mode the Claude Code auto-mode classifier blocked
  `dax_query_operations` ("Modify Shared Resources"); fixed by an allow rule
  `mcp__powerbi-modeling__dax_query_operations` in `~/.claude/settings.json`
  (added 2026-10-14).
- **Uncommitted objects are not queryable:** a DAX query during an open
  transaction fails with "The value for 'ZZ MCP Test' cannot be determined" — queries
  run outside the transaction. Verify with DAX only after commit.
- Committed `measure_operations Create` (no manual transaction) → DAX returns the
  expected value, `INFO.MEASURES()[State] = 1`. Desktop then reports
  `hasUnsavedChanges = true`; the TMDL on disk is unchanged until the user presses
  **Ctrl+S** — after that `Measure.tmdl` contains the measure, and the MCP
  `description` is written as the `///` doc comment above it. Same rule as TOM
  edits: model changes live in Desktop until Ctrl+S.

#### Full test run (2026-10-14, Collector Assignment test copy) — COMPLETED

Done:
1. **Rename column via MCP** (`IsPromise` → `IsPromiseFlag`): the MCP **rewrites all
   dependent measure DAX automatically** (6 measures, values unchanged) — unlike raw
   TOM. The report breaks **silently**: the slicer loses its field, stops filtering,
   page numbers change (CompareScreens: 86 regions). Fix: Ctrl+S → `pbir fields
   replace --from T.Old --to T.New` (validates the new name against the live model)
   → it **missed the slicer's saved selection** (`objects.general.filter`, source
   alias `"Source": "c"`) → grep leftovers `"Old"` / `.Old"` and fix them by regex →
   `pbir validate` (compare error count with the original: 217 = 217, all schema
   false positives) → `reload` → page identical to the original. pbir also does not
   touch bookmarks and visual interactions.
2. See 1 — automatic DAX fix-up confirmed.
3. **`ConnectFolder` (offline)** fails on all our models: Calendar hierarchy levels
   named with zero-width spaces (`level ​`) are merged as duplicates. With the levels
   renamed (scratch copy) it works: changes stay in memory until
   `database_operations ExportToTmdlFolder`; export rewrote **only** the changed file,
   kept CRLF, no BOM. No DAX query/validate offline.
4. **`pbir restore`**: byte-identical in 4.4 s; backups live in
   `%LOCALAPPDATA%\pbir-tools\backups\` (outside `ClientA\BackUp\`).
   CompareScreens `--expect` warning fires correctly; new `--max-regions`
   (default 10) cut a page-wide report from 34 KB to 1.5 KB. Scrollbars appearing
   after reload show up as small grey regions — render noise.
5. `dax_query Validate` catches bad references with position in ~5 ms. UDF via
   `function_operations Create` works (`ZZ.AddPct`). Calc group via
   `CreateGroup` works only after `model_operations RefreshWithXMLA Calculate`
   (before: "does not hold any data"); its column is named after the group, not `Name`.
   `INFO.FUNCTIONS()` has no `Name` column.
7. Refresh `Calculate` works; a full data refresh was deliberately not run (would query
   the client's production SQL).

5 (cont.). Calculated table via `table_operations Create` (`daxExpression`) — the MCP
   itself warns "refresh required"; inactive relationship via `relationship_operations
   Create` (name auto-generated `From_Col_To_Col`) → `RefreshWithXMLA Calculate` →
   `USERELATIONSHIP` works, state 1. **Delete** of relationship, table, calc group, UDF,
   measure all work; model back to 39 tables.
6. **RLS:** `security_role_operations Create` + `CreatePermissions` (filter
   `Employee[Department] = "Collection"`) → `dax_query Execute` with
   `impersonation.roles` → 507 → 253 employees, 8 → 1 departments. ⚠️ Creating/
   deleting a role through the MCP **while Desktop is open** makes Desktop show
   "The Role object with ID … does not exist" (modal) — the Bridge then answers
   "Host is not ready" until the dialog is closed (Cancel). Do RLS edits with Desktop
   closed. **Trace is not useful:** with `filterCurrentSessionOnly` it misses the MCP's
   own queries (they run on other sessions, impersonation switches the "last
   connection"), without it it caught 1 event in 12 s and `Fetch` returned nothing —
   use `getExecutionMetrics` on `Execute` instead.
8. Bridge `screenshot-all --output-dir <dir> --scale 1`: 50 pages in 208 s (~4 s/page),
   3.9 MB — a baseline for whole-report regression (CompareScreens per page).
   Its console output lists every page (~16 KB) — filter it. `open <pbip>` starts a new
   Desktop window but returns immediately with the **old** window's pid — poll
   `status --pid <new>` until `currentFilePath` appears.
9. pbir (each ~1 s): `filters list`, `bookmarks list`, `theme validate`, `fields find`,
   `schema describe <type>` work; `find "<R>/**/card*.Visual"` 5 s / 3.5 KB. `batch`:
   JSON spec v2 (`version`, `name`, `steps[{id, op, select, set, max_targets…}]`, 40 ops
   incl. `field_replace`, `measure_rename`, `filter_*`, `bookmark_*`, `theme_apply`,
   layout); `batch validate` → `batch plan --root` (dry run, plan digest) → `batch run
   --root` (per-step status/time). The `validate_report` step said ok where
   `pbir validate` lists 217 schema false positives — it is more lenient. The batch
   schema itself is 36 KB — read only `definitions.step`.
10. TE2 `-S script.csx -TMDL <out>` on a scratch copy: 3 s, `Info()` prints to the log;
    the TMDL output changed only `Measure.tmdl` (CRLF kept) and `database.tmdl` (TE2 adds
    `compatibilityMode: powerBI`). **TE2 loads our models with the zero-width Calendar
    levels** — the working offline fallback while the MCP's `ConnectFolder` cannot.

Not run on purpose: full data refresh (would query the client's production SQL), MCP
against Fabric/XMLA, the hosted MCP.

State after the run: Collector test copy has unsaved changes in Desktop (all `ZZ`
objects deleted again; the `IsPromiseFlag` rename and its report fix are saved);
a Journal Entries copy is open in a second Desktop window. Close both without saving;
the whole `ClientA\BackUp\2026-10-14_ToolTest\` folder is disposable.
