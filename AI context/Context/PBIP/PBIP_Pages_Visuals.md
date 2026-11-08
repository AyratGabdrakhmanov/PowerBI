# PBIP: pages and visuals

> Part of the PBIP knowledge base (split 2026-10-12). Table of contents and section map — [POWERBI_PBIP_STRUCTURE.md](POWERBI_PBIP_STRUCTURE.md).

> **Split into the folder `PBIP_Pages_Visuals\` on 2026-11-06** — this file is the index, the content is in the files below (moved verbatim; an old reference "PBIP_Pages_Visuals.md → <section>" finds the section by its title here). New content goes into the section file, a new section = a new file + a line here. Convention: `README.md` of this folder's parent.

## Sections

- [Core structure of a PBIP project](PBIP_Pages_Visuals/01_Core_structure_of_a_PBIP_project.md) — 20 lines
- [Three critical places to keep in sync](PBIP_Pages_Visuals/02_Three_critical_places_to_keep_in_sync.md) — 39 lines
- [⚠️ CRITICAL RULES](PBIP_Pages_Visuals/03_CRITICAL_RULES.md) — 80 lines
- [How to rename pages correctly (displayName)](PBIP_Pages_Visuals/04_How_to_rename_pages_correctly_displayName.md) — 19 lines
- [`page.json` schema (`page-2.1.0.json`)](PBIP_Pages_Visuals/05_page_json_schema_page_2_1_0_json.md) — 77 lines
- [Visual structure (visuals/)](PBIP_Pages_Visuals/06_Visual_structure_visuals.md) — 10 lines
  - [Key fields of visual.json](PBIP_Pages_Visuals/07_Key_fields_of_visual_json.md) — 32 lines
  - [`$schema` version of the visual is higher than the publicly released one](PBIP_Pages_Visuals/08_schema_version_of_the_visual_is_higher_than_the.md) — 109 lines
  - [⚠️ Keeping formatting when a visual's fields change (2026-10-22)](PBIP_Pages_Visuals/09_Keeping_formatting_when_a_visuals_fields_change.md) — 45 lines
  - [⚠️ Visuals can reference each other by folder ID](PBIP_Pages_Visuals/10_Visuals_can_reference_each_other_by_folder_ID.md) — 23 lines
  - [⚠️⚠️ Three fields reference a PAGE by its folder name — and this was historically never tracked](PBIP_Pages_Visuals/11_Three_fields_reference_a_PAGE_by_its_folder_name.md) — 110 lines
  - [⚠️⚠️ `parentGroupName` — visual grouping references by folder ID, and old script versions could silently corrupt it](PBIP_Pages_Visuals/12_parentGroupName_visual_grouping_references_by_fo.md) — 95 lines
  - [⚠️ On/Off tab buttons — "On" is not junk, even if hidden and it "does nothing" (ClientB, 2026-10-13)](PBIP_Pages_Visuals/13_On_Off_tab_buttons_On_is_not_junk_even_if_hidden.md) — 32 lines
  - [⚠️ Bookmarks and group visibility — z-order is scoped WITHIN the parent group, not across the whole page](PBIP_Pages_Visuals/14_Bookmarks_and_group_visibility_z_order_is_scoped.md) — 35 lines
  - [⚠️⚠️ Official MS documentation: renaming risks and auto-removal of invalid references from bookmarks](PBIP_Pages_Visuals/15_Official_MS_documentation_renaming_risks_and_aut.md) — 81 lines
  - [⚠️⚠️ Non-ASCII folder name of a page/visual breaks Publish/template export](PBIP_Pages_Visuals/16_Non_ASCII_folder_name_of_a_page_visual_breaks_Pu.md) — 58 lines
  - [Numeric serialization in PowerShell (rounding gotcha)](PBIP_Pages_Visuals/17_Numeric_serialization_in_PowerShell_rounding_got.md) — 15 lines
- [⚠️⚠️ Orphaned page folders (without `page.json`)](PBIP_Pages_Visuals/18_Orphaned_page_folders_without_page_json.md) — 39 lines
- [⚠️ Visual duplication during parallel work](PBIP_Pages_Visuals/19_Visual_duplication_during_parallel_work.md) — 24 lines
- [Power BI Desktop caching](PBIP_Pages_Visuals/20_Power_BI_Desktop_caching.md) — 24 lines
- [Common problems and solutions](PBIP_Pages_Visuals/21_Common_problems_and_solutions.md) — 31 lines
- [displayName vs name structure](PBIP_Pages_Visuals/22_displayName_vs_name_structure.md) — 13 lines
- [Correctness check](PBIP_Pages_Visuals/23_Correctness_check.md) — 29 lines
- [What Power BI does NOT do](PBIP_Pages_Visuals/24_What_Power_BI_does_NOT_do.md) — 20 lines
- [Conclusion](PBIP_Pages_Visuals/25_Conclusion.md) — 8 lines
