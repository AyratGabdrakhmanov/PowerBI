Part of [PBIP_Pages_Visuals.md](../PBIP_Pages_Visuals.md) (split 2026-11-06).

## Numeric serialization in PowerShell (rounding gotcha)

`[Math]::Round(496.667, 0)` returns a **`Double`** (`497.0`), and
`ConvertTo-Json` serializes a `Double`, even a whole one, as `497.0` — with a trailing
`.0` that is not present in Power BI's original files. You need to explicitly cast to an
integer type:

```powershell
$vjson.position.x = [long][Math]::Round([double]$vjson.position.x, 0)
```

`[long]` (`Int64`) is serialized to JSON as a plain integer `497`, without
a decimal point — exactly as Power BI expects.
