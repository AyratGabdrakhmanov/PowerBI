Part of [PBIP_Model_Live.md](../PBIP_Model_Live.md) (split 2026-11-06).

## Querying the open Power BI Desktop model — `QueryOpenModel.ps1` (added 2026-10-04)

TMDL files show the **formulas**, but not the **data**. To test a hypothesis
on real numbers (duplicate rows, monthly totals, reconciliation with SAP), you can
run DAX queries directly against the model open in Power BI Desktop, without DAX
Studio and without access to the SQL server.

### How it works

1. An open `.pbix`/`.pbip` = a local Analysis Services instance running in the background
   (`msmdsrv.exe`) on a **random** port. The model with all
   loaded data lives in it.
2. Desktop writes the port to `msmdsrv.port.txt` (encoding **UTF-16**) in the
   workspace folder:
   - Store version: `%USERPROFILE%\Microsoft\Power BI Desktop Store App\AnalysisServicesWorkspaces\AnalysisServicesWorkspace_<guid>\Data\msmdsrv.port.txt`
   - MSI version: `%LOCALAPPDATA%\Microsoft\Power BI Desktop\AnalysisServicesWorkspaces\...\Data\msmdsrv.port.txt`
3. Connection — **ADOMD.NET** (`Microsoft.AnalysisServices.AdomdClient.dll`),
   connection string `Data Source=localhost:<port>`. Nothing needs to be installed
   separately: the DLL is taken from the installed DAX Studio
   (`C:\Program Files\DAX Studio\bin\`) or Tabular Editor. DAX Studio / Tabular Editor (External Tools)
   connect the same way themselves.

### Script

[`ClientA\_Documentation\Scripts\QueryOpenModel.ps1`](<../../../Scripts/QueryOpenModel.ps1>) — finds the DLL and the
port by itself, runs the query, prints the result as a table (TAB separator):

```powershell
# List of open Desktop instances (port, start time)
powershell -ExecutionPolicy Bypass -File QueryOpenModel.ps1 -ListInstances

# Query as a string (quotes inside DAX - doubled)
powershell -ExecutionPolicy Bypass -File QueryOpenModel.ps1 -Query "EVALUATE ROW(""Rows"", COUNTROWS(Doc_ItemName))"

# Query from a file (handier for long/Hebrew queries - file in UTF-8)
powershell -ExecutionPolicy Bypass -File QueryOpenModel.ps1 -QueryFile q1.dax

# If several files are open - specify the port explicitly
powershell -ExecutionPolicy Bypass -File QueryOpenModel.ps1 -Port 63930 -QueryFile q1.dax
```

Works in both Windows PowerShell 5.1 and PowerShell 7 (verified).

### Limitations and gotchas

- **Read-only.** The script runs `EVALUATE` queries and does not change the model.
  Model edits while Desktop is open — via TOM, see "Editing the open
  model "on the fly" (TOM)" below; while it is closed — via the TMDL files.
- **Only while Desktop is open.** After a restart the port is different. The file
  `msmdsrv.port.txt` may be left over from a closed Desktop — the script discards
  ports that are not listening.
- **Which file is open cannot be seen from the port.** If several
  `.pbix`/`.pbip` files are open — `-ListInstances` and `-Port`. If a query fails with
  `Cannot find table '...'` — most likely another file is already open in Desktop.
  Quick check of which model is connected:
  `EVALUATE SELECTCOLUMNS(INFO.TABLES(), "Name", [Name])`.
- **Data is as of the last Refresh in Desktop**, not live from SQL.
- **Only the first `EVALUATE` is printed** — one query per call.
- The script has no Cyrillic in its body (like the other scripts): Windows PowerShell
  5.1 does not read UTF-8 without BOM. `Add-Type -Path` for this DLL under 5.1 fails
  noisily (`ReflectionTypeLoadException`), so the DLL is loaded via
  `[Reflection.Assembly]::LoadFrom`.

### Useful DAX techniques for diagnostics

- **Duplicate fact rows after a merge in Power Query:** add an index in M
  (`Table.AddIndexColumn`) **before** the merge and compare
  `COUNTROWS(Fact)` with `DISTINCTCOUNT(Fact[Index])`; the total without duplicates —
  `SUMX(SUMMARIZE(Fact, Fact[Index], Fact[Value]), Fact[Value])`.
- **Slice for a period without slicers:**
  `CALCULATETABLE(SUMMARIZECOLUMNS(...), DATESBETWEEN('Date'[Date], DATE(2026,9,1), DATE(2026,9,30)))`.
- **Data boundaries:** `MIN`/`MAX` on the fact's date column — you see right away that
  there is simply no data for the selected period.
- **Testing a new measure without editing the model:** `DEFINE MEASURE 'Measure'[Name]
  = ...` before `EVALUATE`. The `Measure` table — **in quotes**: `Measure` is a
  reserved word; without quotes you get the error "The syntax for 'Measure' is
  incorrect".
- **Set the context that slicers provide on the page explicitly**, otherwise
  measures are blank: `Collector Assignment` — `TREATAS ( { "Units" },
  CT_ReportType[Type] )`, month — `TREATAS ( { ( 2026, DATE ( 2026, 10, 1 ) ) },
  Calendar[Year], Calendar[Month Slicer] )`, page filter
  `Calendar[Closed Period] = TRUE ()`, IsPromise slicer —
  `NOT ISBLANK ( CollectorAssignmentSnapshot[IsPromise] )`.
- **`SUMMARIZECOLUMNS` by a column that the measure overwrites in
  `CALCULATE`** (e.g. by `PTPResult` for `[PTP Resolved]`) gives the same
  value in every row — group by such columns only
  measures that do not overwrite them (`[PTP #/USD]`), or by ID/loan.

### Real-world example: ClientE `Sales Main` (2026-10-04)

Complaint: "sales are overstated compared with SAP". From the TMDL there was only
a suspicion; queries against the open model gave an exact answer within minutes:

- `Doc_ItemName`: 298,781 rows with 266,586 unique `Index` values — a FullOuter
  merge with `TargetsAndSlp` on `SlpCode_Doc_KEY`, and in `ETL_MD_TargetsAndSlp`
  4 salespeople (`200_17`–`200_20`) have two identical rows each → their sales are
  exactly ×2. September 2026, invoices minus zikuyim (credit notes): 2,352,585 in the model versus
  1,440,879 without duplicates.
- `MIN(DocDate)` = 02.01.2024 → the blank "תקופה א" for 2022 was explained by
  the absence of data, not by a measure error (the initial hypothesis based on the
  TMDL alone was wrong — a reason to check on the data, not only on the formulas).
