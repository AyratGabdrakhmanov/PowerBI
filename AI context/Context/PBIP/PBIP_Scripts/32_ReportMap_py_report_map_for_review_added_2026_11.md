Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `ReportMap.py` — report map for review (added 2026-11-05)

`python Scripts\ReportMap.py "<project folder with the .pbip>" "<out.xlsx>" ["<config.json>"]` (openpyxl, so not `-I`) —
read-only xlsx: **Groups** (purpose + pages), **Pages** (tab name He / En, header, page filters with hidden / locked, slicers =
saved default, flags), **Slicers** (field, mode, saved default, agents in a saved list, show-existing filter), **Visuals** (title
He / En from the title measure, fields, visual filters), **Consistency** (per group: month / document type / agent defaults and
page filters; the most common value is the norm, page filters compared by presence + hidden / locked only). The optional config
(page groups, English page names, English values) lives in the **project** folder, never in this repo; pages not in it go to
"? (not grouped)". ClientC `Sales NEW` 2026-11-05: `ClientC\Sales New\ReportMap_config.json`, 43 pages, 182 slicers, 188 visuals,
28 flags.
Config parts `allocations` (concept / rule / source / fields / notes - usage of each field counted from the report) and `model_tables` (DAX `DATATABLE` tables dumped as `Data <table>` sheets) add the sheets **Allocation** and **Data ...** (2026-11-05; ClientC: 12 allocations - area agent, area / sub-area, area manager, document agent, card agent mapping, customer, item family, item group, family / area targets, document type, company; tables `CT_GroupAreas` / `CT_AreaManager` / `CT_Agents`).
