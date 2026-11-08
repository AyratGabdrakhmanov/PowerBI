Part of [AI_Tools_MCP_CLI.md](../AI_Tools_MCP_CLI.md) (split 2026-11-06).

## 7. DAX Studio CLI (`dscmd`) — query benchmark (DAX Studio 3.6.1, used 2026-10-22)

`C:\Program Files\DAX Studio\dscmd.exe` — comes with DAX Studio, nothing to install. `dscmd benchmark` = the
Benchmark of the DAX Studio GUI: cold runs (cache cleared before each) + warm runs, Server Timings per run.

```powershell
& "C:\Program Files\DAX Studio\dscmd.exe" benchmark out.csv -s "localhost:<port>" -d <databaseId> -f query.dax --cold 5 --warm 5 --silent
```

- `-s` — the Desktop port (from MCP `ListLocalInstances`); `-s "<file>.pbip"` should find the open Desktop by
  file name. `-d` — the database ID (a GUID in Desktop): `AdomdConnection.Database` after `Open()`.
- The CSV: one row per run — `Cache, TotalDuration_ms, FormulaEngineDuration_ms, StorageEngineDuration_ms,
  StorageEngineQueryCount, StorageEngineCpu_ms, TotalCpu_ms, VertipaqCacheMatches, RowCount, Error`, then a
  `# Summary` block (averages). Read it with `ConvertFrom-Csv -Header …` — PowerShell header names are
  case-insensitive (`SE` / `SEq` clash).
  ⚠️ Summary rows (`Cold,Average,…`, `Warm,Min,…`) have **no** `Sequence` value, so every number sits one column
  left of the header (`Cache` = statistic, `TotalDuration_ms` = total ms, …) — read them positionally
  (2026-10-22: a parse by header gave empty totals).
- Query-only: clears the cache and runs DAX, no refresh. ~10 runs × query time — a 6 s query × 9 files ran over the
  10-min tool timeout; run long sets in the background.
- Check every query returns the same data first (rows + sum of the value) — a query with a missing slicer filter is
  fast but meaningless. To copy the visual's real query, trace it (MCP `trace_operations` `Start` with
  `filterCurrentSessionOnly: false`, events `QueryEnd`; open the page with `powerbi-desktop screenshot <pageId>`;
  `Fetch` columns `EventClassName, Duration, TextData`).
- Example of use and results: `PBIP_Recipes.md` → "Recipe: drill from a matrix cell…" → "Benchmark".
- Other commands: `csv` / `file` / `xlsx` (export a query result), `vpax` (model statistics).
