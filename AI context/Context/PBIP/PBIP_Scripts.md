# PBIP: scripts

> Part of the PBIP knowledge base (split 2026-10-12). Table of contents and section map — [POWERBI_PBIP_STRUCTURE.md](POWERBI_PBIP_STRUCTURE.md).

## Scripts

⚠️ **The path changed on 2026-09-18:** scripts no longer live in a single flat
`_Context\` — master copies (not tied to a project) are now in
`ClientA\_Documentation\` (`CleanUnused.ps1`, `RenameObjects.ps1`,
`FormatPowerQuery.ps1`) and `ClientA\_Documentation\Scripts\` (until
2026-10-04 — `Scripts\`: `ReplaceModelTable.ps1`, `fix_nonascii_names.ps1`,
`Rename-ReportTheme.ps1`, `QueryOpenModel.ps1`, `PublishPowerBIApp.ps1`).
Project copies of `CleanUnused.ps1`/`RenameObjects.ps1` were deleted on 2026-10-15
(user decision) — every project, Budget vs Actual included, runs the master copy
plus `-RootPath`, see below. The old names `rename_pages.ps1`/
`Find-UnusedMeasures.ps1`/`Replace-ModelTable.ps1` in the text below refer to the same
scripts (`RenameObjects.ps1`/`CleanUnused.ps1`/`ReplaceModelTable.ps1`).
Full list — "Catalog" at the beginning of the file.

**Python with Hebrew output — `-X utf8`, not `PYTHONIOENCODING` (2026-10-18).** `python -I` (isolated
mode, used for every script here) ignores all `PYTHON*` environment variables, so
`PYTHONIOENCODING=utf-8` has no effect and `print` of Hebrew fails on the cp1252 console
(`UnicodeEncodeError`). Use `python -I -X utf8 …`.

**Running the master copy on any project — `-RootPath` (2026-10-13); copying
the script next to the report is no longer needed:** `RenameObjects.ps1`, `CleanUnused.ps1`,
`ReplaceModelTable.ps1`, `fix_nonascii_names.ps1` accept the project folder
(the one containing `*.Report`/`*.SemanticModel`); `RenameObjects.ps1` and
`fix_nonascii_names.ps1` also accept the `*.Report` folder itself. Without `-RootPath` —
the script's own folder (as before). Example:
`pwsh -File "...\ClientA\_Documentation\RenameObjects.ps1" -RootPath "...\Agency\ClientB\Report"`.
The others already took the path as a parameter: `FormatPowerQuery.ps1` (a `.pq` file/folder),
`Rename-ReportTheme.ps1 -ReportPath`, `PublishPowerBIApp.ps1
-PbixPath`; `QueryOpenModel.ps1` works with the open model, not a folder.
⚠️ Also fixed at the same time: when relaunching from Windows PowerShell 5.1 into pwsh,
parameters were lost (`@args` is empty when `param()` is present) — they are now
passed explicitly. `RenameObjects.ps1`: visuals are sorted naturally
(`slicer2` < `slicer10`) — previously every repeated run shifted the
numbers of all `slicerN` again (on ClientB — 338 changed files without a single real
rename).

> **Split into the folder `PBIP_Scripts\` on 2026-11-06** — this file is the index, the content is in the files below (moved verbatim; an old reference "PBIP_Scripts.md → <section>" finds the section by its title here). New content goes into the section file, a new section = a new file + a line here. Convention: `README.md` of this folder's parent.

## Sections

- [Script versioning (`$ScriptVersion`)](PBIP_Scripts/01_Script_versioning_ScriptVersion.md) — 15 lines
- [`RenameObjects.ps1` (formerly `rename_pages.ps1`)](PBIP_Scripts/02_RenameObjects_ps1_formerly_rename_pages_ps1.md) — 176 lines
- [`fix_nonascii_names.ps1`](PBIP_Scripts/03_fix_nonascii_names_ps1.md) — 16 lines
- [`normalize_visuals.ps1` — removed (functionality spread across other scripts)](PBIP_Scripts/05_normalize_visuals_ps1_removed_functionality_spre.md) — 17 lines
- [`Rename-ReportTheme.ps1` (added 2026-09-19)](PBIP_Scripts/06_Rename_ReportTheme_ps1_added_2026_09_19.md) — 30 lines
- [Real-world example: the `Warm` preset (`Collector Assignment`, 2026-09-19)](PBIP_Scripts/07_Real_world_example_the_Warm_preset_Collector_Ass.md) — 44 lines
- [`ReorderThemeColors.ps1` (added 2026-10-16)](PBIP_Scripts/08_ReorderThemeColors_ps1_added_2026_10_16.md) — 30 lines
- [`ReplaceModelTable.ps1` (formerly `Replace-ModelTable.ps1`)](PBIP_Scripts/09_ReplaceModelTable_ps1_formerly_Replace_ModelTabl.md) — 68 lines
- [Small helpers added 2026-10-23 (ClientD Finance JE → JEC migration)](PBIP_Scripts/10_Small_helpers_added_2026_10_23_ClientD_Finance_JE.md) — 26 lines
- [Helpers added 2026-10-24 (ClientB refactoring, `Refactoring.md`)](PBIP_Scripts/11_Helpers_added_2026_10_24_ClientB_refactoring_Refacto.md) — 48 lines
- [`EnterDataToDax.ps1` — internal M tables → DAX `DATATABLE`, live (2026-10-23)](PBIP_Scripts/12_EnterDataToDax_ps1_internal_M_tables_DAX_DATATAB.md) — 16 lines
- [`FindUnusedColumns.py` — is every column used? (report only, 2026-10-23)](PBIP_Scripts/13_FindUnusedColumns_py_is_every_column_used_report.md) — 19 lines
- [`CleanUnused.ps1` (formerly `Find-UnusedMeasures.ps1`)](PBIP_Scripts/14_CleanUnused_ps1_formerly_Find_UnusedMeasures_ps1.md) — 536 lines
- [`FormatPowerQuery.ps1`](PBIP_Scripts/15_FormatPowerQuery_ps1.md) — 33 lines
- [`PbixToPbip.ps1` (added 2026-10-16)](PBIP_Scripts/16_PbixToPbip_ps1_added_2026_10_16.md) — 46 lines
- [`PublishPowerBIApp.ps1`](PBIP_Scripts/17_PublishPowerBIApp_ps1.md) — 26 lines
- [How to run (double-click does not work!)](PBIP_Scripts/18_How_to_run_double_click_does_not_work.md) — 13 lines
- [`ReportFields.py` — report fields and filters (added 2026-10-16)](PBIP_Scripts/19_ReportFields_py_report_fields_and_filters_added.md) — 87 lines
- [`CopyVisualSetup.py` (added 2026-10-15)](PBIP_Scripts/20_CopyVisualSetup_py_added_2026_10_15.md) — 17 lines
- [`CopyDiagramLayout.py` (added 2026-10-15)](PBIP_Scripts/21_CopyDiagramLayout_py_added_2026_10_15.md) — 31 lines
- [`MergeSemanticModel.py` (added 2026-10-20)](PBIP_Scripts/22_MergeSemanticModel_py_added_2026_10_20.md) — 41 lines
- [`ValidateTmdl.ps1` (added 2026-10-20)](PBIP_Scripts/23_ValidateTmdl_ps1_added_2026_10_20.md) — 18 lines
- [`CheckReportRefs.py` (added 2026-10-20)](PBIP_Scripts/24_CheckReportRefs_py_added_2026_10_20.md) — 21 lines
- [`CaptureDesktopWindow.ps1` (added 2026-10-20)](PBIP_Scripts/25_CaptureDesktopWindow_ps1_added_2026_10_20.md) — 39 lines
- [`StackDisconnectedTables.py` (added 2026-10-28)](PBIP_Scripts/26_StackDisconnectedTables_py_added_2026_10_28.md) — 10 lines (superseded by `ArrangeModelView.py`)
- [`ArrangeModelView.py` - Model view layout, step 13 (added 2026-11-07)](PBIP_Scripts/33_ArrangeModelView_py_added_2026_11_07.md) — 18 lines
- [`ChicletToButtonSlicer.py` (added 2026-10-28)](PBIP_Scripts/27_ChicletToButtonSlicer_py_added_2026_10_28.md) — 16 lines
- [`CheckTooltipFit.py` (2026-10-30)](PBIP_Scripts/28_CheckTooltipFit_py_2026_10_30.md) — 6 lines
- [`ClearPbixData.ps1` (added 2026-10-31)](PBIP_Scripts/29_ClearPbixData_ps1_added_2026_10_31.md) — 20 lines
- [`ReportFilters.py` — why is a page / visual blank (added 2026-11-01)](PBIP_Scripts/30_ReportFilters_py_why_is_a_page_visual_blank_adde.md) — 9 lines
- [`SavePbipAsPbix.ps1` — "save pbix" (added 2026-11-01)](PBIP_Scripts/31_SavePbipAsPbix_ps1_save_pbix_added_2026_11_01.md) — 16 lines
- [`ReportMap.py` — report map for review (added 2026-11-05)](PBIP_Scripts/32_ReportMap_py_report_map_for_review_added_2026_11.md) — 12 lines
