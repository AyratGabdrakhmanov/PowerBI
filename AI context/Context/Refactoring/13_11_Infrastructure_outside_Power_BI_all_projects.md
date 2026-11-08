Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 11. Infrastructure outside Power BI (all projects, user 2026-10-26)

Done on the client's server by the user in RDP (no direct access to client data from here; I prepare the scripts), not in the PBIP. Record versions, dates and findings in the project context file.

**11a. Power Loader loads only what the reports need**
- **Companies:** the Power Loader job list (`/RUNONCE:<jobs>`, `CheckPowerLoaderTask.ps1`) vs the companies the reports
  show (`Companies` table / `CompanyID` values in the model). Remove jobs of companies no report uses.
- **Tables:** every `ETL_*` table on the server (`CheckPowerLoaderTables.sql` lists them with rows / size / freshness) is
  loaded by at least one report (`Sql.Database` navigation in all project PBIPs). Unused tables → stop their queries
  in Power Loader (after the user agrees); old copies replaced by a new version (e.g. `ETL_SA_DocsSales` → `ETL_SA_Sales`)
  are removed only when no report of that client still loads them.
- **One pass (ClientB, ClientC 2026-10-27):** user runs `CheckPowerLoaderTables.sql` in RDP (its required list is generic —
  `MISSING` there is not always a problem; `STALE` = older than 2 h, normal for daily loaders) + screenshots of every
  universe → I map table ↔ task ↔ report ↔ reading SQL in `<Client>_Context.md` ("Power Loader tables") → one keep list →
  the user publishes the new report, checks Lineage, unticks all old tasks at once and runs
  `PowerLoader Scripts\DropOldEtlTables_<client>.sql` (part 1 = check `UsedBy` empty, part 2 = `DROP TABLE IF EXISTS`).
  Before dropping: a table a kept SQL reads (`ETL_SA_Payments` ← `Sales_v3`) stays; the old published report still
  loads the old tables until the new one replaces it.
- **Columns:** each SQL outputs only the columns the model uses (`prod_coverage.py` — `Refactoring\ClientC\`; unused
  columns stay commented in the SQL, step 7).
- **Rows:** `$Param_$YearsBack` and the SQL filters (`transfered <> 'Y'`, `TreeType <> 'I'`, card type, …) match the
  oldest period any page shows. Check: rows / size per table before and after (`CheckPowerLoaderTables.sql`).

**11b. Refresh failure alerts**
- **Power Loader fails:** Task Scheduler sends nothing; the task ends with `0x1` (`RunPowerLoaderTask.ps1` decodes the
  result). Alert = a scheduled check after each run: last task result + stale `ETL_*` tables
  (`CheckPowerLoaderTask.ps1` / `CheckPowerLoaderTables.sql` logic) → email (Microsoft Graph, as ReportMailer's
  `admin_email`, `Infrastructure.md`). **To build** — one self-contained script per server.
- **Power BI fails:** Service → each semantic model → Settings → *Refresh* → *Send refresh failure notifications to*:
  the owner + our address (`ayrat@Agency.com`) + the client contact. Gateway: *Manage connections and gateways* →
  gateway → *Send notifications to these contacts when this gateway is offline*. Check every scheduled model.

**11c. Monthly updates (first week of the month, outside the refresh schedule)**
- On the client's server: **Gateway** (Microsoft supports only the last 6 monthly releases), **Power BI Desktop**,
  **SSMS** — `Agency\Gateway Scripts\UpdateGatewayPowerBIDesktopSSMS.ps1` (in place, gateway registration kept);
  version before / after — `CheckGateway.ps1` (also shows how Power BI Service sees the gateway). While the gateway
  updates, refreshes through it fail. Automatic instead (since 2026-11-07): `SetupUpdateTask.ps1` — weekly task, Fridays
  20:00, watched by TaskAlert (`Infrastructure.md` → `Gateway Scripts`). Done: SAP-Server-2 (ClientB).
- Our workstation: Desktop (standalone + Store), DAX Studio / Tabular Editor (`UpdateExternalTools.ps1`).
- Record the versions + date in the project context file; next check = first week of next month.

**11d. Offer the client DirectQuery (DQ) for fresh data (user 2026-10-27)**
- Today the data is as fresh as the last Power Loader run + the last Power BI refresh (Pro: up to 8 scheduled refreshes a day).
  Ask which pages need "now" data (e.g. today's sales / open orders); everything else stays Import.
- Options, cheapest first: (1) more Power Loader runs aligned with the refresh schedule; (2) composite model — a small DQ
  table for today's documents (SQL view on SAP, current day only) next to the imported history, measures add both;
  (3) hybrid table (Import history + DQ partition for the current period) — needs Premium / PPU / Fabric capacity.
- DQ on the Power Loader tables does not help (they are only as fresh as the last run): the DQ source must be SAP
  (a view in the SAP database or a linked view) — check the query load on the SAP SQL server and the gateway (DQ goes
  through it on every visual interaction).
- DQ limits to tell the client: slower visuals, some DAX / Power Query features unavailable, a gateway is required;
  record the decision in the project context file.
