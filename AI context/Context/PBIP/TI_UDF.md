# Time-intelligence UDFs `TI.*` — single source

- **Reference script:** `C:\Users\ayrat\OneDrive\Документы\ClientA\_Documentation\Reference\DAX PRO Solutions\TI_UDF.tmdl` —
  46 functions (13 comparisons × absolute + `Pct`, 20 building blocks), TMDL view script (`createOrReplace`).
- **Tested source:** `Reference\DAX PRO Solutions\TI UDF Sample\` (64 functions = the reference set + extras below);
  checks `Scripts\TI_Checks.dax` (105: Calendar health, arithmetic, wrapper = measure, totals); regenerate the reference
  from the sample, never edit it by hand.
- **Refactoring:** step 30 (apply), step 31 (switch measures / CG items) — `Refactoring.md`.
- **Logic source:** the user's `CG Time Intelligence` (Sales Channels). DAX Lib packages (XU.TMDL.TimeIntelligence & co.)
  were a coverage checklist only.

## Catalog (reference set)

| Pattern | M | Q | Y |
|---|---|---|---|
| To date | `MTD` | `QTD` | `YTD` |
| To date vs previous period to date | `MTDvsPMTD` | `QTDvsPQTD` | `YTDvsPYTD` |
| To date vs same to-date last year | `MTDvsPYMTD` | `QTDvsPYQTD` | `YTDvsPYTD` |
| To date vs full previous period | `MTDvsFullPM` | `QTDvsFullPQ` | `YTDvsFullPY` |
| Period vs previous period | `MOM` (MTD vs PM) | `QOQ` (QTD vs PQ) | `YOY` (period vs PY) |
| To date vs full same period last year | `MTDvsFullPYM` | `QTDvsFullPYQ` | `YTDvsFullPY` |

Each comparison: `TI.<name>` = absolute, `TI.<name>Pct` = %. Building blocks: `Change`, `ChangePct`, `ChangeIfBoth`,
`ChangePctIfBoth`, `MTD`, `QTD`, `YTD`, `PM`, `PQ`, `PY`, `PMTD`, `PQTD`, `PYTD`, `PYMTD`, `PYQTD`, `PMC`, `PQC`, `PYC`,
`PYMC`, `PYQC`. Sample-only extras: `CUM`, `DTD`, `PD`, `DOD`, `DLY`, `MODLY`, `PYCN`, `MAT`, `PYMAT`, `MATG`,
`RollingMonths`, `MovingAvg`, `LastNMonths`, `YTDToMonth`, `HideFuture`.

Formats: functions carry none — on the measure, absolute `+#,##0;-#,##0`, % `+#,0%;-#,0%;0%`.

## Behaviour by selected grain (checked 2026-10-31, `Scripts\TI_GrainCheck.py`: 210 / 210)

To-date functions take the **last** day / month / quarter in context; `TI.PY`, `TI.YOY` take the whole selection;
`TI.PYC` = the whole previous year. Example, last year (LY), previous year (LLY):

| Selected | `MTD` / `PM` | `QTD` / `PQ` | `YTD` / `PYTD` | `PY` (YOY) |
|---|---|---|---|---|
| Day 15 May | 1–15 May / 1–15 Apr | 1 Apr–15 May / 1 Jan–15 Feb | 1 Jan–15 May / same LLY | 15 May LLY |
| Month May | May / Apr | Apr–May / Jan–Feb | Jan–May / same LLY | May LLY |
| Quarter Q2 | **Jun** / May | Q2 / Q1 | Jan–Jun / same LLY | Q2 LLY |
| Year | **Dec** / Nov | **Q4** / Q3 | year / LLY | LLY |
| Range Feb–Apr | **Apr** / Mar | **Apr** / Jan | Jan–Apr / same LLY | Feb–Apr LLY |

- A quarter or year selected → MOM = its last month vs the month before (June vs May, December vs November).
- A range crossing quarters is **not** one period for the to-date functions: Feb–Apr → `QTD` = April only, `QOQ` =
  April vs January; only `YOY` compares the whole range. Use whole months / quarters on such visuals.
- `Full` functions: the whole previous month / quarter / year of the last period (`PMC`, `PQC`, `PYMC`, `PYQC`).

## Rules and gotchas (2026-10-31)

- **Totals follow the last period in context (`DATESMTD` / `DATESQTD` pattern):** `TI.PM` = `DATEADD ( DATESMTD (
  Date ), -1, MONTH )`, `TI.PQ` = `DATEADD ( DATESQTD ( Date ), -1, QUARTER )`, `TI.MOM` = MTD vs PM, `TI.QOQ` = QTD vs
  PQ — a Year total shows December vs November / Q4 vs Q3. The XU form `DATEADD ( 'Calendar'[Date], -1, MONTH )` shifts
  the whole year by a month (a Year total = Dec LLY–Nov LY, nonsense). No `HASONEVALUE` guard: it would blank the
  CG's deliberate Year totals (`PMC` "DATESMTD for Total on Year level").
- **Year comparisons blank without current data:** `TI.ChangeIfBoth` / `TI.ChangePctIfBoth` (`* DIVIDE ( cur, cur )`,
  CG YOY pattern) for YOY / YTDvsPYTD / QTDvsPYQTD / MTDvsPYMTD / *vsFullPY* / MATG, also on `Pct`; other comparisons use
  `TI.Change` / `TI.ChangePct` (blank only when the previous value is blank / 0).
- **Names say what is compared:** `TI.<cur>vs<prev>` (`TI.MTDvsPYMTD`), `Full` = the whole previous period
  (`TI.MTDvsFullPM`); `Pct` suffix = % version (UDF names allow no `%` / `Δ`). To-date functions with a whole period
  selected compare that period (data so far, if unfinished) with the whole previous one.
- **`MAX`, not `LASTDATE`** (`TI.DTD`): `LASTDATE` returns a table and does a hidden context transition when the UDF
  is called inside an iterator (SQLBI). Test gotcha: `CALCULATE ( [X], LASTDATE ( Date ), <period> )` evaluates
  `LASTDATE` **outside** `<period>` (filter arguments use the outer context) — nest a `CALCULATE`.
- **No display folders for functions:** `INFO.USERDEFINEDFUNCTIONS ()` has only `Name`, `Description`, `Expression`,
  `IsHidden`, `State`, `ErrorMessage`, … — grouping only by dotted names (`TI.`).
- **Check after apply:** `FILTER ( INFO.USERDEFINEDFUNCTIONS (), LEFT ( [Name], 3 ) = "TI." )` — count and
  `[State] = 1`; plus one hand-computed comparison on a base measure.
- **Desktop asks "save changes?" after opening a PBIP with hand-added functions** (it adds lineage tags) — the files
  are already correct: close with `Stop-Process` (= Don't save, no UI click); `functions.tmdl` stays as written.
- **Multi-line function in TMDL:** the opening ```` ``` ```` goes on the header line, before the parameters:
  `function 'X' = ```` ``` ```` → `( p : EXPR ) =>` → body → closing ```` ``` ````. A fence after `=>` loads with State 5
  "Invalid token, Line 2" (Sales v2 2026-11-02). One-line bodies need no fence.
- **Model needs:** compatibility level 1705 (1606 models — e.g. ClientB Inventory Coverage — need the upgrade first,
  user decision), `'Calendar'[Date]` marked as date table (`dataCategory: Time` + `isKey`; the reference `Calendar.json`
  is marked since 2026-10-31).

## Appendix: grain check result (2026-10-31, TI UDF Sample, LY = 2025)

210 rows (31 functions + their `Pct` versions × 5 grains), 210 pass. Dates dd.mm, LY unless marked LLY;
comparisons = current vs previous. Rerun: `python -I Scripts\TI_GrainCheck.py <out.dax>` → `QueryOpenModel.ps1`.

| Function | Day 15 May | Month May | Quarter Q2 | Year | Range Feb–Apr |
|---|---|---|---|---|---|
| `TI.MTD` | 01.05–15.05 | 01.05–31.05 | 01.06–30.06 | 01.12–31.12 | 01.04–30.04 |
| `TI.QTD` | 01.04–15.05 | 01.04–31.05 | 01.04–30.06 | 01.10–31.12 | 01.04–30.04 |
| `TI.YTD` | 01.01–15.05 | 01.01–31.05 | 01.01–30.06 | 01.01–31.12 | 01.01–30.04 |
| `TI.PM` | 01.04–15.04 | 01.04–30.04 | 01.05–31.05 | 01.11–30.11 | 01.03–31.03 |
| `TI.PMTD` | 01.04–15.04 | 01.04–30.04 | 01.05–31.05 | 01.11–30.11 | 01.03–31.03 |
| `TI.PQ` | 01.01–15.02 | 01.01–28.02 | 01.01–31.03 | 01.07–30.09 | 01.01–31.01 |
| `TI.PQTD` | 01.01–15.02 | 01.01–28.02 | 01.01–31.03 | 01.07–30.09 | 01.01–31.01 |
| `TI.PY` | 15.05–15.05 LLY | 01.05–31.05 LLY | 01.04–30.06 LLY | 01.01–31.12 LLY | 01.02–30.04 LLY |
| `TI.PYTD` | 01.01–15.05 LLY | 01.01–31.05 LLY | 01.01–30.06 LLY | 01.01–31.12 LLY | 01.01–30.04 LLY |
| `TI.PYMTD` | 01.05–15.05 LLY | 01.05–31.05 LLY | 01.06–30.06 LLY | 01.12–31.12 LLY | 01.04–30.04 LLY |
| `TI.PYQTD` | 01.04–15.05 LLY | 01.04–31.05 LLY | 01.04–30.06 LLY | 01.10–31.12 LLY | 01.04–30.04 LLY |
| `TI.PMC` | 01.04–30.04 | 01.04–30.04 | 01.05–31.05 | 01.11–30.11 | 01.03–31.03 |
| `TI.PQC` | 01.01–31.03 | 01.01–31.03 | 01.01–31.03 | 01.07–30.09 | 01.01–31.03 |
| `TI.PYC` | 01.01–31.12 LLY | 01.01–31.12 LLY | 01.01–31.12 LLY | 01.01–31.12 LLY | 01.01–31.12 LLY |
| `TI.PYMC` | 01.05–31.05 LLY | 01.05–31.05 LLY | 01.06–30.06 LLY | 01.12–31.12 LLY | 01.04–30.04 LLY |
| `TI.PYQC` | 01.04–30.06 LLY | 01.04–30.06 LLY | 01.04–30.06 LLY | 01.10–31.12 LLY | 01.04–30.06 LLY |
| `TI.MTDvsPMTD` | 01.05–15.05 vs 01.04–15.04 | 01.05–31.05 vs 01.04–30.04 | 01.06–30.06 vs 01.05–31.05 | 01.12–31.12 vs 01.11–30.11 | 01.04–30.04 vs 01.03–31.03 |
| `TI.QTDvsPQTD` | 01.04–15.05 vs 01.01–15.02 | 01.04–31.05 vs 01.01–28.02 | 01.04–30.06 vs 01.01–31.03 | 01.10–31.12 vs 01.07–30.09 | 01.04–30.04 vs 01.01–31.01 |
| `TI.YTDvsPYTD` | 01.01–15.05 vs 01.01–15.05 LLY | 01.01–31.05 vs 01.01–31.05 LLY | 01.01–30.06 vs 01.01–30.06 LLY | 01.01–31.12 vs 01.01–31.12 LLY | 01.01–30.04 vs 01.01–30.04 LLY |
| `TI.MTDvsPYMTD` | 01.05–15.05 vs 01.05–15.05 LLY | 01.05–31.05 vs 01.05–31.05 LLY | 01.06–30.06 vs 01.06–30.06 LLY | 01.12–31.12 vs 01.12–31.12 LLY | 01.04–30.04 vs 01.04–30.04 LLY |
| `TI.QTDvsPYQTD` | 01.04–15.05 vs 01.04–15.05 LLY | 01.04–31.05 vs 01.04–31.05 LLY | 01.04–30.06 vs 01.04–30.06 LLY | 01.10–31.12 vs 01.10–31.12 LLY | 01.04–30.04 vs 01.04–30.04 LLY |
| `TI.MTDvsFullPM` | 01.05–15.05 vs 01.04–30.04 | 01.05–31.05 vs 01.04–30.04 | 01.06–30.06 vs 01.05–31.05 | 01.12–31.12 vs 01.11–30.11 | 01.04–30.04 vs 01.03–31.03 |
| `TI.QTDvsFullPQ` | 01.04–15.05 vs 01.01–31.03 | 01.04–31.05 vs 01.01–31.03 | 01.04–30.06 vs 01.01–31.03 | 01.10–31.12 vs 01.07–30.09 | 01.04–30.04 vs 01.01–31.03 |
| `TI.YTDvsFullPY` | 01.01–15.05 vs 01.01–31.12 LLY | 01.01–31.05 vs 01.01–31.12 LLY | 01.01–30.06 vs 01.01–31.12 LLY | 01.01–31.12 vs 01.01–31.12 LLY | 01.01–30.04 vs 01.01–31.12 LLY |
| `TI.MOM` | 01.05–15.05 vs 01.04–15.04 | 01.05–31.05 vs 01.04–30.04 | 01.06–30.06 vs 01.05–31.05 | 01.12–31.12 vs 01.11–30.11 | 01.04–30.04 vs 01.03–31.03 |
| `TI.QOQ` | 01.04–15.05 vs 01.01–15.02 | 01.04–31.05 vs 01.01–28.02 | 01.04–30.06 vs 01.01–31.03 | 01.10–31.12 vs 01.07–30.09 | 01.04–30.04 vs 01.01–31.01 |
| `TI.YOY` | 15.05–15.05 vs 15.05–15.05 LLY | 01.05–31.05 vs 01.05–31.05 LLY | 01.04–30.06 vs 01.04–30.06 LLY | 01.01–31.12 vs 01.01–31.12 LLY | 01.02–30.04 vs 01.02–30.04 LLY |
| `TI.MTDvsFullPYM` | 01.05–15.05 vs 01.05–31.05 LLY | 01.05–31.05 vs 01.05–31.05 LLY | 01.06–30.06 vs 01.06–30.06 LLY | 01.12–31.12 vs 01.12–31.12 LLY | 01.04–30.04 vs 01.04–30.04 LLY |
| `TI.QTDvsFullPYQ` | 01.04–15.05 vs 01.04–30.06 LLY | 01.04–31.05 vs 01.04–30.06 LLY | 01.04–30.06 vs 01.04–30.06 LLY | 01.10–31.12 vs 01.10–31.12 LLY | 01.04–30.04 vs 01.04–30.06 LLY |
