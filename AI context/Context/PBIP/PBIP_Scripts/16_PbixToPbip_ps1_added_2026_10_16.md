Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `PbixToPbip.ps1` (added 2026-10-16)

File: [`ClientA\_Documentation\Scripts\PbixToPbip.ps1`](<../../../Scripts/PbixToPbip.ps1>).
Converts a `.pbix` into a PBIP project (`<Name>.pbip` + `.Report` + `.SemanticModel`),
the same layout as Desktop's "Save as > .pbip". The `.pbix` is only read.

```powershell
powershell -ExecutionPolicy Bypass -File PbixToPbip.ps1 -Pbix "C:\Reports\Sales.pbix" [-OutDir "C:\PBIP\Sales"]
```

- **Model** — the `DataModel` inside a `.pbix` is compressed (XPress9), so it is read from
  the Desktop that has the file open: `powerbi-desktop status` → pid → child `msmdsrv.exe`
  → listening port → TOM `TmdlSerializer.SerializeDatabaseToFolder`. If the file is not
  open, the script opens it (`Start-Process`) and **leaves Desktop open**. TOM DLL — the
  newest of Tabular Editor 2 / DAX Studio. `database.tmdl` gets the workspace GUID name
  removed (as Desktop writes it).
- **Report** — copied from the zip: new `.pbix` already contain PBIR (`Report/definition/…`);
  old ones contain `Report/Layout` → `report.json` (PBIR-legacy, Desktop upgrades it on
  save). Also `StaticResources`, `CustomVisuals`, `DiagramLayout` → `diagramLayout.json`,
  `TMDLScripts`, `DAXQueries`. UTF-16 parts are rewritten as UTF-8 without BOM.
- Writes `definition.pbir` (4.0, `byPath`), `definition.pbism` (4.2), `.platform` (new
  `logicalId`), `.pbip`, `.gitignore` (if missing). Refuses to overwrite existing output.
- **Data, no Refresh** — the `.pbix` `DataModel` stream is the same XPress9 ABF backup that
  Desktop keeps as `<Name>.SemanticModel\.pbi\cache.abf` (identical header); the script
  copies it byte for byte, and the `.pbip` opens with data. Checked on an M/Excel table:
  4 rows in the `.pbix` = 4 in the `.pbip`; without `cache.abf` — empty. `cache.abf` is in
  `.gitignore`. A `Backup` through TOM is not an option: Desktop's engine runs Diskless
  ("Backup/Restore … not supported … in Diskless mode").
- **No Desktop window (version `2026-10-31.1`):** with the MSI Desktop installed (`C:\Program Files\Microsoft Power BI Desktopin\msmdsrv.exe`)
  the script starts that engine hidden (own temp folder, port from `msmdsrv.port.txt`), loads the `.pbix` `DataModel` with
  `Server.ImageLoad`, serializes TMDL and stops the engine — approach of pbi-tools (MIT; its `msmdsrv.ini` template is too
  minimal). Engine settings = Desktop's own `msmdsrv.ini` saved as `Scripts\PbixToPbip_msmdsrv.ini` (cleaned: no M engine
  pipe, no encrypted parts): without `Feature/DynamicCalcColumn` the load fails on per-viewer (`userContext`) columns
  ("UserContext expression context should only be set … Direct Lake tables"), `DAX/UserDefinedFunctions` is needed for UDFs.
  After a Desktop update, refresh the template from a live workspace `…\AnalysisServicesWorkspaces\*\Data\msmdsrv.ini`
  if a load fails on a new feature. No MSI Desktop → the old Desktop-window route. Checked 2026-10-31: ClientC
  `Sales NEW.pbix` (34 MB) in ~1 min, 31 tables / 208 measures / 21 relationships = the PBIP; report 1,028 / 1,029 files
  JSON-equal (only `activePageName`).
- Not supported: live-connected (thin) reports with no `DataModel` — the script stops.
- ⚠️ Desktop must be started with `Start-Process` (ShellExecute), not `powerbi-desktop
  open`: a Desktop started as a child inherits the console's output handles, and the
  calling shell then waits until Desktop is closed.
- Checked 2026-10-16 on copies of `Calendar.pbix` (DAX PRO, PBIR report), `How to enable the
  Single Value option…pbix` (legacy `Report/Layout`) and `ClientC\DuplSource.pbix` (M import):
  ~1 min including Desktop start; each `.pbip` opened with its pages and no unsaved changes.
