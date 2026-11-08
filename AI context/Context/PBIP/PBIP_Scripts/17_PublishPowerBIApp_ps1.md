Part of [PBIP_Scripts.md](../PBIP_Scripts.md) (split 2026-11-06).

## `PublishPowerBIApp.ps1`

File: [`ClientA\_Documentation\Scripts\PublishPowerBIApp.ps1`](<../../../Scripts/PublishPowerBIApp.ps1>).
Publishes a finished `.pbix` (built from PBIP via Desktop, Save As) to
one or more Power BI Service workspaces, overwriting
(`New-PowerBIReport -ConflictAction CreateOrOverwrite`).

- Parameters: `-WorkspaceNames` (default `"Executive Dashboards"`,
  `"Subscribtions"`), `-PbixPath` (default
  `Semantic Model\Semantic Model.pbix`), `-ReportName`
  (default — the file name, i.e. `Semantic Model`, the model's Service name since 2026-10-24),
  `-Force` (no `y/N` prompt).
- Installs the `MicrosoftPowerBIMgmt` module itself (`-Scope CurrentUser`, without
  administrator rights); sign-in is interactive
  (`Connect-PowerBIServiceAccount`), Service Principal — for the future.
- If a workspace is not found, or several with the same name are found — skips it with
  a message.
- Each workspace gets an **independent** copy of the report and dataset:
  refresh, data source credentials and subscriptions are configured in each one
  separately.
- ⚠️ **"Update app" — manually.** The public REST API has no endpoint for
  updating an App (verified against the MS documentation, 2026-09-06; previously the script
  called the non-existent `groups/{id}/UpdateApp` → 404). Only Deployment Pipelines
  can do this automatically (Premium/Fabric,
  `options.updateAppSettings`).
