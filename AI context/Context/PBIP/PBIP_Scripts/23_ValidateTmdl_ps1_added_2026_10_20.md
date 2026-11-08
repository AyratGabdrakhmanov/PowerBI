Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `ValidateTmdl.ps1` (added 2026-10-20)

`ClientA\_Documentation\Scripts\ValidateTmdl.ps1` — offline check that a TMDL folder loads with the TOM
TMDL loader (the one MS MCP `ConnectFolder` and Tabular Editor use), before opening it in Desktop.

```
pwsh -File ValidateTmdl.ps1 -Path "<X.SemanticModel>"      # or its definition folder; -TomDll to override the DLL
```

- Prints `OK  tables=… (calculated …)  measures=…  relationships=…  expressions=…` or the loader's error with
  file and line (`TMDL Format Error … Document './tables/Grade Bands' Line Number 74`). Exit code 0 / 1.
- Works on a scratch copy in `%TEMP%` (removed after): zero-width hierarchy level names (`level ​`, our
  Calendar) are replaced there with quoted NBSP — the loader rejects them as duplicates, Desktop does not
  (`PBIP_Model_Live.md`, invisible level names). The model files are never changed.
- Loads structure only: DAX inside measures is not evaluated — measure errors show up in the open model
  (`INFO.MEASURES ()` `[State]`, `PBIP_Model_Live.md` → "Checking the model for errors").
- ModelWork 2026-10-20: merged Model — 68 tables, 660 measures, 55 relationships; before the merge 60 / 582 / 53.
