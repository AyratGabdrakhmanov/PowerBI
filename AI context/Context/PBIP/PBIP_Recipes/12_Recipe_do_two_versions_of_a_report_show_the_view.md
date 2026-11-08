Part of [PBIP_Recipes.md](../PBIP_Recipes.md) (split 2026-11-06).

## Recipe: do two versions of a report show the viewer the same figures? (ClientB, 2026-10-25)

Scripts: `ClientA\_Documentation\Scripts\CompareReportViews\` (written for the ClientB run: report keys `cur` / `pdf`, ports as
parameters or at the top of `split.py` — adjust before reuse).
1. Open both versions in Desktop; check both models hold the same data (row counts, sums, min / max date) — otherwise
   every difference is data.
2. MCP `trace_operations` `Start` on each port: events `QueryEnd`, `filterCurrentSessionOnly: false`.
3. Render every page with `powerbi-desktop screenshot <page> --pid` (+ a few seconds), logging each page's UTC
   start / end → `pages_log.csv`; a failed screenshot still renders — keep its window too.
4. `ExportJSON` both traces → `split.py` (queries → pages by time) → `run_queries.ps1` (rerun each query on its own
   model; **read all result sets** — a matrix query returns column headers first, the body second) → `compare.py`
   (results as sorted value rows, column names ignored) → `pairdiff.py id id` (rows keyed by text columns, numeric
   columns compared with sums).
5. Read the filters of differing queries (`__DS0FilterTable…` block) and diff the saved selections:
   `saved_diff.py <old Report> <new Report>` — lost / changed slicer selections and visual date filters.
6. Measure-level fallback: `common_measures.ps1` — every measure with the same name, under date contexts (without a
   date filter, time-intelligence measures differ by calendar range only).
Gotchas: Desktop caches identical queries (a slicer repeated on pages queries once); the landing page renders before
the trace starts (needs a reload — can restart Desktop, new port, see `AI_Tools_MCP_CLI.md`); a windowed visual returns
only its first rows (~500 / 1 001) — compare such matrices at shared levels or by a direct query; a two-column slicer
(quarter + month) filters by a tuple, not `TREATAS ( { … }, col )`; `Calendar` name columns are dates with a format
(`\Qd`, `mmm`) — `datetime'2026-04-02'` = Q2 is correct.
