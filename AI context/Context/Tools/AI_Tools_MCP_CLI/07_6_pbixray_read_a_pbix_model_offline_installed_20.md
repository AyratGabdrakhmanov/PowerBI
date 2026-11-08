Part of [AI_Tools_MCP_CLI.md](../AI_Tools_MCP_CLI.md) (split 2026-11-06).

## 6. pbixray — read a .pbix model offline (installed 2026-10-20)

- What: Python library that decompresses the `DataModel` inside a `.pbix` (XPress9 ABF) and
  returns model metadata without Desktop: tables, columns + data types (`schema`), M queries
  (`power_query`), measures (`dax_measures`), calculated columns / tables, relationships, RLS,
  column statistics. Read-only; does not see the report layer (unzip the pbix for that —
  a pbix saved in PBIR format has `Report/definition/` with the same files as a PBIP).
- Install (not on the global site-packages, so it does not touch other projects):
  `python -m pip install --target "$env:LOCALAPPDATA\pbixray" pbixray` → 0.15.5 on Python 3.14.
  Upgrade: the same command with `--upgrade`.
- Use: `python -I -X utf8 "ClientA\_Documentation\Scripts\DumpPbixModel.py" <file.pbix> <out.json>`
  — writes everything to JSON, prints only object counts (read details from the JSON with a
  script, not by eye). `-X utf8` is required: Hebrew names crash the default cp1252 console.
- Typical tasks: compare a `.pbix` with its PBIP (`DumpPbixModel.py` output vs the TMDL files),
  inspect a client pbix without opening it in Desktop.
- **Data, offline (2026-11-01):** `PBIXRay(f).get_table('<Table>')` returns the rows as a pandas DataFrame — import
  tables, calculated columns (e.g. ClientC `Customers[Agent]`) and calculated tables (`Calendar`, incl. TODAY()-based
  labels as of the last refresh). Good for checking figures for a client letter (join `Sales` + dimensions in pandas,
  apply the report filters by hand: company, currency, open / all column, document types) without Desktop. Measures
  are not evaluated — rebuild the logic or use Desktop + DAX. ~1–2 min for a 35 MB pbix.
- Fields returned: measures — table, name, expression, display folder, description; columns
  (`schema`) — table, name, pandas data type only; relationships — from/to, active,
  cardinality, cross-filter.
- Limits: not a full TOM — no translations/cultures, perspectives, format strings, sort-by,
  hidden flags, column display folders or annotations; for those open the file in Desktop
  and use the MS Modeling MCP.
- ⚠️ `relationships` misses every relationship that touches a calculated table (Sales_ClientB,
  2026-10-20: 9 returned vs 18 in TMDL — all missing ones go to `Calendar`, `CT_Language`,
  `Dates - Period B`, `Target`, calc tables). Do not read "absent in pbixray" as "absent in
  the model".
