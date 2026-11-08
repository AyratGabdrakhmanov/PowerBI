Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 31. Switch current time-intelligence measures to `TI.*` UDFs (all projects, user 2026-10-31 — next step after 30)

1. **Find:** explicit measures with `DATESYTD` / `DATESQTD` / `DATESMTD` / `DATEADD` / `SAMEPERIODLASTYEAR` /
   `PARALLELPERIOD` / `DATESINPERIOD` / `TOTALYTD` (BPA `BP_TI_IN_CALC_GROUP`, `BP_TI_ON_CALENDAR_DATE`) and the items
   of `CG Time Intelligence`.
2. **Switch:** `CALCULATE ( [X], SAMEPERIODLASTYEAR ( 'Calendar'[Date] ) )` → `TI.PY ( [X] )`, a hand-written
   `( cur - prev ) * DIVIDE ( prev, prev )` → `TI.<comparison> ( [X] )`. The base measure stays as is (Sales Channels
   pattern, step 15: `SalesValue` / `Profit` / `Quantities` with the selector IDs) — the UDF wraps the base measure,
   never repeats the selector logic.
3. **Sales Channels approach (reference `CG Time Intelligence`, checked 2026-10-31):** UDF = CG item for CUM, YTD, QTD,
   MTD, PD, PY, PYC, PYTD, PYQTD, PYMTD, PMTD, PMC, PQ (QTD shifted, 2026-10-31), YOMTD, YOQTD, MOM (MTD − PMTD), QOQ
   (QTD − PQ, 2026-10-31), MODLY, DOD; year comparisons blank when the current value is blank (`TI.ChangeIfBoth` /
   `TI.ChangePctIfBoth` = CG `* DIVIDE ( cur, cur )`, also on the % versions — the CG has it on the absolute ones only).
   Kept different on purpose: (c) CG `'YOY %'` compares **YTD** with PY (`YOY` compares the period) — CG bug,
   `TI.YOYPct` = period; (d) CG `PYMC` = `PARALLELPERIOD ( DATESMTD, -1, YEAR )` = the whole previous year, `TI.PYMC` =
   the whole same month last year; (e) CG `DTD` = `LASTDATE`, `TI.DTD` = `MAX` (SQLBI). Week items (`CW`, `PW`, `WOW`,
   `CW PY`, `CW Over PY`) are `BLANK ()` placeholders / use a missing `WTD` item — no UDF.
4. **Check (as step 15):** every switched measure × every selector state × total / year / quarter / month equal before
   and after, except the differences above that were settled as fixes.
5. **How (ClientF Sales v2 2026-11-02, first run):** live TOM on the open model — measure `Expression` = `TI.<x> ( [Base] )`,
   CG item = `TI.<x> ( SELECTEDMEASURE() )` (EXPR parameters take `SELECTEDMEASURE()`); measures that had no format
   string (they never got the CG item's) get one. Snapshot only the changed measures and their dependants
   (`SnapshotMeasures.ps1 -Measures`): all measures × months ran > 40 min on TopN / Pareto measures. Items without a
   reference UDF stay (CUM, DTD, PD, DOD, DLY, MODLY, week items), also rolling-window measures (`DATESINPERIOD` from
   `TODAY`). ⚠️ A calculated table `SUMMARIZE ( Fact, …, CALCULATE ( [Measure] ) )` over a fact related to a table with a
   UserContext column blocks every `SaveChanges` that touches the measure ("cannot reference the UserContext calculated
   column") → `SUMMARIZECOLUMNS ( Fact[Key], "…", [Measure] )` (same rows, no row context), then Calculate that table.
6. **Remove the CG after the switch (ClientF Sales v2 2026-11-05):** visuals / filters / DAX on `'CG Time Intelligence'`
   → explicit `TI.<x> ( [Base] )` measures (captions = the base measure's, so legends stay), check CG item = measure per
   year × month, then drop the table + its culture translations (TOM) and the visual filters on it.
