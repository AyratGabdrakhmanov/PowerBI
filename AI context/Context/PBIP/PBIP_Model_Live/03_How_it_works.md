Part of [PBIP_Model_Live.md](../PBIP_Model_Live.md) (split 2026-11-06).

## How it works

The same local `msmdsrv.exe` and port as for `QueryOpenModel.ps1`, but via
**TOM** (`Microsoft.AnalysisServices.Tabular.dll` from
`C:\Program Files\DAX Studio\bin\`) — this is how Tabular Editor and
other External Tools write to the model. The report layer (visuals) does not live
in Analysis Services, so TOM does not see it.

```powershell
[void][Reflection.Assembly]::LoadFrom("C:\Program Files\DAX Studio\bin\Microsoft.AnalysisServices.Tabular.dll")
$srv = New-Object Microsoft.AnalysisServices.Tabular.Server
$srv.Connect("Data Source=localhost:<port>")      # port - QueryOpenModel.ps1 -ListInstances
$model = $srv.Databases[0].Model
$c = $model.Tables["CollateralAction"].Columns["RepoType"]
$c.Name = "RepoTypeGroup"; $c.SourceColumn = "RepoTypeGroup"
$model.SaveChanges() | Out-Null
$srv.Disconnect()
```

Works in PowerShell 7 (verified 2026-10-06).
