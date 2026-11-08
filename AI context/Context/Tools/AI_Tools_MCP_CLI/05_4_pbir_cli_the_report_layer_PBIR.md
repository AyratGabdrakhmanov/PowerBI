Part of [AI_Tools_MCP_CLI.md](../AI_Tools_MCP_CLI.md) (split 2026-11-06).

## 4. pbir-cli — the report layer (PBIR)

- ⚠️ `pbir report convert <x>.pbix -F pbip` (tested 2026-10-31, 0.9.32) converts only thin reports: a `.pbix` with a data
  model stops with "thick PBIX … cannot be programmatically converted", open in Desktop. Our `PbixToPbip.ps1` does it
  without Desktop (hidden engine). pbi-tools (MIT, <https://github.com/pbi-tools/pbi-tools>) uses the same engine method
  but its `msmdsrv.ini` template lacks Desktop features (per-viewer columns, UDFs) and its folder layout is not PBIP — not
  installed; only its `AnalysisServicesServer.cs` was read for the method.

- <https://github.com/maxanatsko/pbir.tools>, authors Kurt Buhler and Maxim
  Anatsko. Version **0.9.32** (beta), closed source (binary wheel).
- ⚠️ License **Custom Non-Commercial** (commercial use — with
  written permission from the authors). Use confirmed by the user
  2026-10-14.
- Installed: `pip install --user` → `%APPDATA%\Python\Python314\Scripts\pbir.exe`;
  the folder is added to the user PATH (in new terminals — just `pbir`).
- Addressing: `Report.Report/Page.Page/Visual.Visual`, glob `**/*.Visual`,
  properties via dot notation. Run from the folder containing `*.Report`.
- Main commands: `ls`, `tree`, `find`, `cat`, `get`; `set`, `rm`, `cp`,
  `mv`, `add`, `new`; `fields`, `filters`, `bookmarks`, `dax` (only
  report-level measures and visual calcs, **not the model**); `theme`, `schema`;
  `report rename|rebind|convert|merge|split`; `backup`, `restore`,
  `validate`; `batch`.
- Rules: before editing — `pbir backup` **and** our backup in `ClientA\BackUp\`;
  after each edit — `pbir validate`; before `set` — `pbir schema describe
  <type> <object>` (do not guess properties); bulk/deleting operations
  require `-f`. Desktop open → after editing — `powerbi-desktop reload`
  (or Apply external changes).
- Baseline 2026-10-23: `pbir validate "Collector Assignment.Report"` = **62 errors, 86 warnings** (all
  pre-existing). After an edit, compare item by item, not just counts:
  `pbir -q --output-format json validate <report>` → `pages[].visuals[].issues[]` (`code`, `location`),
  set difference against the original. New visuals that copy a newer `visualContainer` schema version get
  only `SCHEMA_DEGRADED` / `SCHEMA_PROCESSED_SUPPORT_UNAVAILABLE` notices, which are harmless.
- Verified: `pbir validate Model_v2.Report` (ClientA\Model) — 13 errors
  `SCHEMA_ERROR` on `actionButton` (`spaceAboveDivider`/`spaceAbovePlotArea`/
  `spaceAboveSubtitle` "unexpected"). Probably the properties are newer than the schema
  `pbir` knows — do not fix blindly, check against
  [visualContainerSchema-2.13.0.json](../../PBIP/Schemas/visualContainerSchema-2.13.0.json) +
  [visualConfigurationSchema-2.8.0.json](../../PBIP/Schemas/visualConfigurationSchema-2.8.0.json).
  **Confirmed 2026-10-15:** all three are valid `Spacing` properties since
  `visualConfiguration` 2.6.0 (Jul 2026) — false positives of pbir's older bundled schema.
  **Confirmed 2026-10-14:** `pbir set` warns "Declared schema 'visualContainer'
  version '2.12.0' is not available locally; validation used bundled fallback
  schema" — our visuals are on schema 2.12.0, pbir 0.9.32 validates against an
  older one, so these `SCHEMA_ERROR`s are false positives. Ignore them (compare
  error counts before/after an edit instead of expecting zero).
- `pbir set` **has `--dry-run`** (not in the README) — use it before bulk edits.
- **Updating pbir's schemas (2026-10-15).** pbir 0.9.32 (latest on GitHub/PyPI as of 15 Oct)
  bundles `visualContainer` 2.9.0 / `visualConfiguration` 2.3.0 / theme 2.155. The official
  `pbir schema fetch [--regenerate]` is anonymous only (no token support — checked in the binary)
  and fails on GitHub's 60 requests/hour limit. Working route — pbir's documented manual one
  ("`pbir schema regenerate`: use this after manually updating raw schemas"): put the new
  version folders into `<site-packages>\pbir_binary_wheel\runtime\pbir_object_model\schemas\
  report\<type>\<version>\` (`schema.json` + `schema-embedded.json` where the repo has it),
  raise `"version"` for that type in `schema_summary.json`, run `pbir schema regenerate`.
  Automated daily by [UpdateSchemas.ps1](<../../../Scripts/UpdateSchemas.ps1>) (task
  `UpdatePowerBISchemas`, 09:00; also theme + semanticModel; log `Context\PBIP\Schemas\SchemaUpdates.log`).
  Result on ClientB: 362 → 90 warnings (2.12.0 visuals validated exactly). **Still 1 error:** for
  an unpublished `$schema` (2.13.0) pbir falls back to the version compiled into the binary
  (`bundled_schema_version 2.9.0`), not to added files — goes away only with a new pbir release
  or when Microsoft publishes 2.13.0. A pbir upgrade replaces the folder; the next daily run
  re-adds newer versions.
