# PBIP: working with the model — queries, TOM, DAX UDF

> Part of the PBIP knowledge base (split 2026-10-12). Table of contents and section map — [POWERBI_PBIP_STRUCTURE.md](POWERBI_PBIP_STRUCTURE.md).
> Ready-made tools for the same tasks (MS Power BI Modeling MCP, Desktop Bridge CLI, TE2 CLI, `pbir`) — [AI_Tools_MCP_CLI.md](../Tools/AI_Tools_MCP_CLI.md) (2026-10-14).

> **Split into the folder `PBIP_Model_Live\` on 2026-11-06** — this file is the index, the content is in the files below (moved verbatim; an old reference "PBIP_Model_Live.md → <section>" finds the section by its title here). New content goes into the section file, a new section = a new file + a line here. Convention: `README.md` of this folder's parent.

## Sections

- [Querying the open Power BI Desktop model — `QueryOpenModel.ps1` (added 2026-10-04)](PBIP_Model_Live/01_Querying_the_open_Power_BI_Desktop_model_QueryOp.md) — 102 lines
- [Editing the open model "on the fly" (TOM) — rule since 2026-10-06](PBIP_Model_Live/02_Editing_the_open_model_on_the_fly_TOM_rule_since.md) — 40 lines
  - [How it works](PBIP_Model_Live/03_How_it_works.md) — 21 lines
  - [Order and gotchas](PBIP_Model_Live/04_Order_and_gotchas.md) — 170 lines
  - [Checking the model for errors after edits (2026-10-13)](PBIP_Model_Live/05_Checking_the_model_for_errors_after_edits_2026_1.md) — 48 lines
  - [Fixing a visual after renaming — directly in the folder (decision 2026-10-06)](PBIP_Model_Live/06_Fixing_a_visual_after_renaming_directly_in_the_f.md) — 26 lines
  - [Example: Collateral, 2026-10-06](PBIP_Model_Live/07_Example_Collateral_2026_10_06.md) — 10 lines
- [Invisible hierarchy level names — use quoted NBSP, not zero-width spaces (2026-10-14)](PBIP_Model_Live/08_Invisible_hierarchy_level_names_use_quoted_NBSP.md) — 73 lines
- [DAX User-Defined Functions (`functions.tmdl`)](PBIP_Model_Live/09_DAX_User_Defined_Functions_functions_tmdl.md) — 194 lines
