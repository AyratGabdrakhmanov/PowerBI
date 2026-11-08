Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `FormatPowerQuery.ps1`

File: [`ClientA\_Documentation\FormatPowerQuery.ps1`](<../../Rules/FormatPowerQuery.ps1>);
the rules it applies — [Power Query Formatting Rules.md](<../../Rules/Power Query Formatting Rules.md>)
(keep the exceptions list `$script:NameOverrides` identical in the script and in that
file). Formats M queries (`.pq`) saved from Power
Query as text:

1. Auto step names `#"Added Custom"` → the name of the called function without
   the namespace (`Table.AddColumn` → `AddColumn`); exception —
   `Table.TransformColumnTypes` → `Typed`.
2. A repeated name within one query → suffix `AddColumn2`, `AddColumn3`.
3. All references to a renamed step (further down the chain and in `in`)
   are updated.
4. Removes steps with no effect (`Table.ReorderColumns`,
   `Table.SelectRows(..., each true)`), redirecting references to their input.
5. `Table.AddColumn` + an immediately following `Table.TransformColumnTypes` only
   for that column → a single `Table.AddColumn(..., type)`, if the result of
   `AddColumn` is not used anywhere else.

```powershell
powershell -ExecutionPolicy Bypass -File "FormatPowerQuery.ps1" "C:\...\Query.pq"
powershell -ExecutionPolicy Bypass -File "FormatPowerQuery.ps1" "C:\...\PowerQuery"   # all *.pq in the folder
```

- Requires PowerShell 7 (relaunches itself in `pwsh`).
- Writes the file in place (UTF-8 without BOM), **makes no backup** — make a copy
  manually before running.
- Designed for a flat `let ... in`, as Desktop generates; a step with
  a nested `let...in` is not handled — check hand-written queries by eye.
- The `_clean` suffix rule in the file name (a query without transformations) is
  not automated.
